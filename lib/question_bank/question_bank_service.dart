/// 题库内存服务：分组管理 + 加权随机抽题。
///
/// 采用 cache-aside 模式：内存缓存提供同步读，写操作先改内存再
/// write-through 到可选的 [QuestionRepository]；无 repo 注入时（测试/demo）
/// 行为退化为纯内存。持久化写入异步执行，调用方可通过 [flush] 等待落库。
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/repositories/question_repository.dart';
import 'bank_question.dart';
import 'question_group.dart';

/// 题库服务（ChangeNotifier），分组增删改后通知 UI 刷新。
class QuestionBankService extends ChangeNotifier {
  /// 最近抽过不重复的记忆容量：抽题时会尽量避开最近抽过的题。
  QuestionBankService({
    this.recentMemorySize = 10,
    this.maxWeight = 8,
    this._repository,
  })  : assert(recentMemorySize >= 0, 'recentMemorySize 不能为负'),
        assert(maxWeight >= 1, 'maxWeight 至少为 1');

  /// 可选的持久化后端；为 `null` 时纯内存。
  final QuestionRepository? _repository;

  /// 串行的写入门：每次写入等待上一次完成后再执行，
  /// 保证同一题目的 insert→update 顺序不被并发打乱。
  Future<void> _lastWrite = Future<void>.value();

  /// 从 DB 载入全部分组与题目，并按累计答错次数初始化内存权重。
  ///
  /// 供启动时调用；调用前应清空内存状态（首次构造时默认为空）。
  /// 无 [repository] 时为空操作。
  Future<void> loadFromDb() async {
    final repo = _repository;
    if (repo == null) return;
    final groups = await repo.loadAll();
    final counts = await repo.loadAllCounts();
    _groups
      ..clear()
      ..addAll(groups);
    _weights.clear();
    for (final entry in counts.entries) {
      final w = _weightFromWrongCount(entry.value.wrong);
      if (w > 1) _weights[entry.key] = w;
    }
    notifyListeners();
  }

  /// 等待全部挂起的 DB 写入完成（测试用）。
  Future<void> flush() => _lastWrite;

  /// 把一次异步写入串入写入门，吞掉异常（内存已是最新值）。
  void _persist(Future<void> Function() op) {
    if (_repository == null) return;
    _lastWrite = _lastWrite.then((_) => op()).catchError((_) {});
  }

  /// 由累计答错次数推导初始权重：每次答错翻倍，封顶 [maxWeight]。
  int _weightFromWrongCount(int wrongCount) {
    if (wrongCount <= 0) return 1;
    final shifts = min(wrongCount, _log2(maxWeight));
    return min(1 << shifts, maxWeight);
  }

  static int _log2(int n) {
    var k = 0;
    while ((1 << k) < n) {
      k++;
    }
    return k;
  }

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
    _persist(() => _repository!.insertGroup(group));
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
    _persist(() => _repository!.insertGroup(group));
    notifyListeners();
    return group;
  }

  /// 重命名分组。
  void renameGroup(String groupId, String name) {
    _mutateGroup(groupId, (group) {
      final updated = group.copyWith(name: name);
      _persist(() => _repository!.updateGroup(updated));
      return updated;
    });
  }

  /// 切换分组启用状态。
  void setGroupEnabled(String groupId, bool enabled) {
    _mutateGroup(groupId, (group) {
      final updated = group.copyWith(enabled: enabled);
      _persist(() => _repository!.updateGroup(updated));
      return updated;
    });
  }

  /// 删除分组，同时清理其题目的权重与最近抽题记录。
  void removeGroup(String groupId) {
    final index = _groups.indexWhere((group) => group.id == groupId);
    if (index == -1) return;
    for (final question in _groups[index].questions) {
      _forgetQuestion(question.id);
    }
    _groups.removeAt(index);
    _persist(() => _repository!.softDeleteGroup(groupId));
    notifyListeners();
  }

  /// 向分组追加题目（手动添加或导入到现有分组）。
  void addQuestions(String groupId, List<BankQuestion> questions) {
    if (questions.isEmpty) return;
    _mutateGroup(
      groupId,
      (group) {
        final updated =
            group.copyWith(questions: [...group.questions, ...questions]);
        _persist(() => _repository!.insertQuestions(groupId, questions));
        return updated;
      },
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
    _persist(() => _repository!.softDeleteQuestions(ids));
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
      _persist(() => _repository!.updateQuestion(
            questionId,
            question: trimmedQuestion,
            answer: trimmedAnswer,
            hint: trimmedHint,
          ));
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
    } else {
      _weights[questionId] = min(weightOf(questionId) * 2, maxWeight);
    }
    _persist(() => _repository!.bumpCount(questionId, correct: correct));
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

  /// 创建带默认数据的服务，供 UI 假数据驱动阶段使用。
  ///
  /// 默认题库为纯英文分组（与 [main.dart] 中的 `_seedDefaultQuestionBank`
  /// 英文部分保持一致），用户可自行导入所需题库。
  factory QuestionBankService.demo() {
    final service = QuestionBankService();
    service.importIntoNewGroup(
      name: 'Missing Piece',
      questions: [
        BankQuestion(
          question: 'Better a cruel truth than a comfortable ___.',
          answer: 'delusion',
          hint: 'Synonym: illusion, false belief',
        ),
        BankQuestion(
          question: 'A journey of a thousand miles begins with a single ___.',
          answer: 'step',
          hint: 'Synonym: pace, stride',
        ),
      ],
    );
    service.importIntoNewGroup(
      name: 'Curious Mind',
      questions: [
        BankQuestion(
          question: 'What is the molecular formula of water?',
          answer: 'H2O',
          hint: 'Two hydrogen atoms and one oxygen atom',
        ),
        BankQuestion(
          question:
              'What is the speed of light in vacuum, approximately (in km/s)?',
          answer: '300000',
          hint: 'About 3 × 10^5 km/s',
        ),
      ],
    );
    return service;
  }
}
