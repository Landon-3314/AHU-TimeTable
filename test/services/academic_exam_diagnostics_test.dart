import 'package:flutter_test/flutter_test.dart';
import 'package:AnKe/services/academic_exam_diagnostics.dart';

void main() {
  test('summarizes exam diagnostic snapshot into bounded log lines', () {
    final lines = AcademicExamDiagnostics.summarizeSnapshot(
      {
        'href': 'https://jw.ahu.edu.cn/student/for-std/exam-arrange/info/99358',
        'title': '考试安排',
        'readyState': 'complete',
        'documentLength': 1200,
        'bodyTextLength': 340,
        'iframes': [
          {
            'href': 'https://jw.ahu.edu.cn/student/for-std/exam-arrange/frame',
            'title': 'iframe',
            'readyState': 'complete',
            'bodyTextLength': 80,
            'scriptSrcs': ['https://jw.ahu.edu.cn/assets/exam.js'],
          },
        ],
        'scriptSrcs': ['https://jw.ahu.edu.cn/assets/app.js'],
        'resources': [
          {
            'initiatorType': 'fetch',
            'name': 'https://jw.ahu.edu.cn/student/for-std/exam-arrange/data',
            'duration': 12.5,
          },
        ],
        'networkRequests': [
          {
            'type': 'fetch',
            'method': 'GET',
            'url': 'https://jw.ahu.edu.cn/student/for-std/exam-arrange/data',
            'status': 200,
            'contentType': 'application/json',
            'bodyLength': 123,
            'snippet': '[{"course":{"nameZh":"离散数学"}}]',
          },
        ],
        'windowKeys': ['studentExamList', 'examStore'],
        'storageKeys': {
          'local': ['exam-cache'],
          'session': ['student-id'],
        },
        'dom': {
          'examTableCount': 0,
          'unfinishedRowCount': 2,
          'examTextNodeCount': 3,
        },
        'errors': ['FRAME_ACCESS_ERROR: blocked'],
      },
      stage: 'after-refresh',
      maxItems: 2,
    );

    expect(
      lines,
      contains(
        'exam diag after-refresh page href=https://jw.ahu.edu.cn/student/for-std/exam-arrange/info/99358 title=考试安排 ready=complete docLength=1200 bodyTextLength=340 frames=1',
      ),
    );
    expect(
      lines,
      contains(
        'exam diag after-refresh dom examTables=0 unfinishedRows=2 examTextNodes=3',
      ),
    );
    expect(
      lines,
      contains(
        'exam diag after-refresh network fetch GET https://jw.ahu.edu.cn/student/for-std/exam-arrange/data status=200 contentType=application/json bodyLength=123 snippet=[{"course":{"nameZh":"离散数学"}}]',
      ),
    );
    expect(
      lines,
      contains(
        'exam diag after-refresh keys window=studentExamList,examStore localStorage=exam-cache sessionStorage=student-id',
      ),
    );
    expect(
      lines,
      contains(
        'exam diag after-refresh frame href=https://jw.ahu.edu.cn/student/for-std/exam-arrange/frame title=iframe ready=complete bodyTextLength=80 scripts=https://jw.ahu.edu.cn/assets/exam.js',
      ),
    );
    expect(
      lines,
      contains(
        'exam diag after-refresh resource fetch https://jw.ahu.edu.cn/student/for-std/exam-arrange/data duration=12.5',
      ),
    );
    expect(
      lines,
      contains('exam diag after-refresh error FRAME_ACCESS_ERROR: blocked'),
    );
  });
}
