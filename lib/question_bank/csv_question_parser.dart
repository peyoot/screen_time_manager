/// 题库 CSV 导入解析。
///
/// 支持的 CSV 格式（RFC 4180 子集）：
/// - 首行为表头，必须包含 `question` 与 `answer` 列，`hint` 列可选，
///   列名大小写不敏感、允许首尾空白；其余列忽略；
/// - 每题一行，字段以英文逗号分隔；
/// - 字段可用双引号包裹以包含逗号/换行，字段内的双引号转义为 `""`；
/// - 引号必须包裹整个字段（紧邻逗号或行首），不支持 `ab"c` 这类写法；
/// - 空行跳过。
library;

import 'bank_question.dart';

/// 解析题库 CSV 文本，返回题目列表。
///
/// 抛出 [FormatException] 的情况：
/// - CSV 为空或表头缺少 `question`/`answer` 列；
/// - 某行的 `question` 或 `answer` 为空；
/// - 存在未闭合引号或字段中间出现引号等非法语法。
///
/// 表头之后若没有任何数据行，返回空列表（由调用方决定是否报错）。
List<BankQuestion> parseCsvQuestions(String csv) {
  final records = _splitCsvRecords(csv)
      .where((record) => record.any((field) => field.trim().isNotEmpty))
      .toList();
  if (records.isEmpty) {
    throw const FormatException('CSV 内容为空');
  }

  // 解析表头，定位各列下标（大小写不敏感、允许空白）。
  final header = records.first
      .map((cell) => cell.trim().toLowerCase())
      .toList(growable: false);
  final questionIndex = header.indexOf('question');
  final answerIndex = header.indexOf('answer');
  final hintIndex = header.indexOf('hint');
  if (questionIndex == -1 || answerIndex == -1) {
    throw const FormatException('CSV 表头必须包含 question 与 answer 列'
        '（示例：question,answer,hint）');
  }

  String cell(List<String> row, int index) =>
      index >= 0 && index < row.length ? row[index].trim() : '';

  final questions = <BankQuestion>[];
  for (var row = 1; row < records.length; row++) {
    final cells = records[row];
    final question = cell(cells, questionIndex);
    final answer = cell(cells, answerIndex);
    final hint = cell(cells, hintIndex);
    if (question.isEmpty || answer.isEmpty) {
      throw FormatException('CSV 第 ${row + 1} 行：question 与 answer 不能为空');
    }
    questions.add(
      BankQuestion(question: question, answer: answer, hint: hint.isEmpty ? null : hint),
    );
  }
  return questions;
}

/// 将 CSV 文本切分为记录（每条记录为字段列表）。
///
/// 手写状态机解析：双引号内逗号/换行视为字段内容，`""` 转义为 `"`；
/// 记录分隔符为 `\r\n`、`\n` 或 `\r`（仅限引号外）。
List<List<String>> _splitCsvRecords(String input) {
  // 兼容 UTF-8 BOM。
  var text = input;
  if (text.startsWith('\uFEFF')) {
    text = text.substring(1);
  }

  final records = <List<String>>[];
  var field = StringBuffer();
  var record = <String>[];
  var inQuotes = false;

  var i = 0;
  while (i < text.length) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          // 转义的双引号。
          field.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      field.write(ch);
      i++;
      continue;
    }
    if (ch == '"') {
      if (field.isNotEmpty) {
        throw FormatException('CSV 字段中间出现非法引号（位置 $i）');
      }
      inQuotes = true;
      i++;
      continue;
    }
    if (ch == ',') {
      record.add(field.toString());
      field = StringBuffer();
      i++;
      continue;
    }
    if (ch == '\r' || ch == '\n') {
      // \r\n 视为一个记录分隔符。
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
        i++;
      }
      record.add(field.toString());
      field = StringBuffer();
      records.add(record);
      record = <String>[];
      i++;
      continue;
    }
    field.write(ch);
    i++;
  }

  if (inQuotes) {
    throw const FormatException('CSV 存在未闭合的双引号');
  }
  // 收尾最后一条记录（文件不以换行结束的情况）。
  if (field.isNotEmpty || record.isNotEmpty) {
    record.add(field.toString());
    records.add(record);
  }
  return records;
}
