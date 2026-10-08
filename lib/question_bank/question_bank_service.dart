/// 题库内存服务：分组管理 + 加权随机抽题。
///
/// 当前阶段全部数据保存在内存中（假数据驱动），接入持久化时只需替换
/// 该类内部实现，UI 与状态机不受影响。抽题结果后续将供答题豁免页使用。
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import 'bank_question.dart';
import 'question_group.dart';

/// 题库服务（ChangeNotifier），分组增删改后通知 UI 刷新。
class QuestionBankService extends ChangeNotifier {
  /// 最近抽过不重复的记忆容量：抽题时会尽量避开最近抽过的题。
  QuestionBankService({this.recentMemorySize = 10, this.maxWeight = 8})
      : assert(recentMemorySize >= 0, 'recentMemorySize 不能为负'),
        assert(maxWeight >= 1, 'maxWeight 至少为 1');

  /// 最近抽过不重复的记忆容量。
  final int recentMemorySize;

  /// 答错加权后的权重上限，防止某道题权重无限膨胀。
  final int maxWeight;

  final List<QuestionGroup> _groups = [];

  /// 题目 id -> 当前权重（缺省为 1）。
  final Map<String, int> _weights = {};

  /// 最近抽中的题目 id（尾部最新），容量受 [recentMemorySize] 限制。
  final List<String> _recentIds = [];

  /// 全部分组（只读视图）。
  List<QuestionGroup> get groups => List.unmodifiable(_groups);

  /// 最近抽中的题目 id（只读视图，尾部最新）。
  List<String> get recentDrawnIds => List.unmodifiable(_recentIds);

  /// 查询某道题当前权重（未加权过的题返回 1）。
  int weightOf(String questionId) => _weights[questionId] ?? 1;

  /// 按 id 查找分组，找不到返回 `null`。
  QuestionGroup? groupById(String id) {
    for (final group in _groups) {
      if (group.id == id) return group;
    }
    return null;
  }

  // ------------------------------------------------------------------
  // 分组管理
  // ------------------------------------------------------------------

  /// 新建一个空分组并返回。
  QuestionGroup createGroup(
    String name, {
    String type = 'input',
    bool enabled = true,
  }) {
    final group = QuestionGroup(
      name: name,
      type: type,
      enabled: enabled,
      questions: const [],
    );
    _groups.add(group);
    notifyListeners();
    return group;
  }

  /// 导入数据创建新分组并返回。
  QuestionGroup importIntoNewGroup({
    required String name,
    String? type,
    required List<BankQuestion> questions,
  }) {
    final group = QuestionGroup(
      name: name,
      type: type ?? 'input',
      questions: questions,
    );
    _groups.add(group);
    notifyListeners();
    return group;
  }

  /// 重命名分组。
  void renameGroup(String groupId, String name) {
    _mutateGroup(groupId, (group) => group.copyWith(name: name));
  }

  /// 切换分组启用状态。
  void setGroupEnabled(String groupId, bool enabled) {
    _mutateGroup(groupId, (group) => group.copyWith(enabled: enabled));
  }

  /// 删除分组，同时清理其题目的权重与最近抽题记录。
  void removeGroup(String groupId) {
    final index = _groups.indexWhere((group) => group.id == groupId);
    if (index == -1) return;
    for (final question in _groups[index].questions) {
      _forgetQuestion(question.id);
    }
    _groups.removeAt(index);
    notifyListeners();
  }

  /// 向分组追加题目（手动添加或导入到现有分组）。
  void addQuestions(String groupId, List<BankQuestion> questions) {
    if (questions.isEmpty) return;
    _mutateGroup(
      groupId,
      (group) => group.copyWith(questions: [...group.questions, ...questions]),
    );
  }

  /// 批量删除分组内指定 id 的题目，并清理对应权重与最近抽题记录。
  void removeQuestions(String groupId, Iterable<String> questionIds) {
    final ids = questionIds.toSet();
    if (ids.isEmpty) return;
    _mutateGroup(groupId, (group) {
      for (final question in group.questions) {
        if (ids.contains(question.id)) {
          _forgetQuestion(question.id);
        }
      }
      return group.copyWith(
        questions:
            group.questions.where((q) => !ids.contains(q.id)).toList(),
      );
    });
  }

  /// 编辑分组内指定 id 的题目（题干/答案/提示）。
  ///
  /// 保持题目 id 不变，因此既有的答错权重与抽题记忆不受影响。
  /// 分组或题目不存在时静默忽略；题干或答案为空白时抛出 [ArgumentError]。
  void updateQuestion(
    String groupId,
    String questionId, {
    required String question,
    required String answer,
    String? hint,
  }) {
    final trimmedQuestion = question.trim();
    final trimmedAnswer = answer.trim();
    final trimmedHint = hint?.trim();
    if (trimmedQuestion.isEmpty || trimmedAnswer.isEmpty) {
      throw ArgumentError('题干和答案不能为空');
    }
    _mutateGroup(groupId, (group) {
      final exists = group.questions.any((q) => q.id == questionId);
      if (!exists) return group;
      return group.copyWith(
        questions: [
          for (final q in group.questions)
            if (q.id == questionId)
              BankQuestion(
                id: q.id,
                question: trimmedQuestion,
                answer: trimmedAnswer,
                hint: trimmedHint == null || trimmedHint.isEmpty
                    ? null
                    : trimmedHint,
              )
            else
              q,
        ],
      );
    });
  }

  // ------------------------------------------------------------------
  // 随机抽题
  // ------------------------------------------------------------------

  /// 从所有 `enabled == true` 的分组中不放回地随机抽取 [count] 道题。
  ///
  /// 抽取规则：
  /// 1. 候选池只包含启用分组的题目；
  /// 2. 优先排除最近 [recentMemorySize] 次抽过的题，避免连续重复；
  ///    候选不足 [count] 时放宽该约束（题库很小时保证能抽满）；
  /// 3. 按 [weightOf] 权重加权抽取，答错加权后的题更容易被抽中。
  ///
  /// 每次抽取成功后会把结果记入"最近抽过"列表；调用方在用户作答后
  /// 应通过 [recordAnswer] 反馈对错以调整权重。
  ///
  /// 启用分组中的题目总数不足 [count] 时抛出 [ArgumentError]。
  List<BankQuestion> drawQuestions(int count, {Random? random}) {
    if (count <= 0) {
      throw ArgumentError.value(count, 'count', '抽取数量必须大于 0');
    }
    final pool = [
      for (final group in _groups)
        if (group.enabled) ...group.questions,
    ];
    if (pool.length < count) {
      throw ArgumentError(
        '启用分组中的题目总数（${pool.length}）少于抽取数量（$count）',
      );
    }

    // 优先排除最近抽过的题；候选不足时回退到全量池。
    final recent = _recentIds.toSet();
    var candidates =
        pool.where((question) => !recent.contains(question.id)).toList();
    if (candidates.length < count) {
      candidates = pool;
    }

    // 加权不放回抽取。
    final rng = random ?? Random();
    final items = List<BankQuestion>.of(candidates);
    final drawn = <BankQuestion>[];
    for (var round = 0; round < count; round++) {
      var total = 0;
      for (final item in items) {
        total += weightOf(item.id);
      }
      var roll = rng.nextInt(total);
      var pickIndex = 0;
      for (var i = 0; i < items.length; i++) {
        roll -= weightOf(items[i].id);
        if (roll < 0) {
          pickIndex = i;
          break;
        }
      }
      drawn.add(items.removeAt(pickIndex));
    }

    // 记录最近抽过的题，容量超限时淘汰最旧的。
    for (final question in drawn) {
      _recentIds.add(question.id);
    }
    while (_recentIds.length > recentMemorySize) {
      _recentIds.removeAt(0);
    }
    return drawn;
  }

  /// 记录一次作答结果：答错将题目权重翻倍（不超过 [maxWeight]），
  /// 答对则恢复默认权重。
  void recordAnswer(String questionId, {required bool correct}) {
    if (correct) {
      _weights.remove(questionId);
      return;
    }
    _weights[questionId] = min(weightOf(questionId) * 2, maxWeight);
  }

  // ------------------------------------------------------------------
  // 内部实现
  // ------------------------------------------------------------------

  /// 就地修改分组并通知监听者；分组不存在时静默忽略。
  void _mutateGroup(
    String groupId,
    QuestionGroup Function(QuestionGroup group) mutate,
  ) {
    final index = _groups.indexWhere((group) => group.id == groupId);
    if (index == -1) return;
    _groups[index] = mutate(_groups[index]);
    notifyListeners();
  }

  /// 清理某道题的权重与最近抽题记录。
  void _forgetQuestion(String questionId) {
    _weights.remove(questionId);
    _recentIds.remove(questionId);
  }

  /// 创建带示例数据的服务，供 UI 假数据驱动阶段使用。
  factory QuestionBankService.demo() {
    final service = QuestionBankService();
    service.importIntoNewGroup(
      name: '安全知识',
      questions: [
        BankQuestion(
          question: '发生火灾时，应拨打的火警电话是多少？',
          answer: '119',
          hint: '三位数的应急电话',
        ),
        BankQuestion(
          question: '红灯亮时，行人应该怎么做？',
          answer: '停在路口等待绿灯',
          hint: '遵守交通信号',
        ),
        BankQuestion(
          question: '雷雨天可以在大树下躲雨吗？',
          answer: '不可以',
          hint: '高大的树木容易引雷',
        ),
      ],
    );
    service.importIntoNewGroup(
      name: '生活常识',
      questions: [
        BankQuestion(
          question: '二十四节气中的第一个节气是什么？',
          answer: '立春',
          hint: '春天的开始',
        ),
        BankQuestion(question: '人体最大的器官是什么？', answer: '皮肤'),
        BankQuestion(
          question: '水的化学式是什么？',
          answer: 'H2O',
          hint: '两个氢原子、一个氧原子',
        ),
      ],
    );
    final spare = service.importIntoNewGroup(
      name: '备用题库',
      questions: [
        BankQuestion(question: '圆周率约为多少？（保留两位小数）', answer: '3.14'),
        BankQuestion(question: '光速约为每秒多少万公里？', answer: '30万'),
      ],
    );
    // 演示"停用"状态的分组：抽题时会跳过它。
    service.setGroupEnabled(spare.id, false);
    return service;
  }
}
