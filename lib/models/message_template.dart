class MessageTemplate {
  final String type; // 'assignment' | 'grading'
  final String content;

  MessageTemplate({
    required this.type,
    required this.content,
  });

  Map<String, dynamic> toMap() => {
        'type': type,
        'content': content,
      };

  factory MessageTemplate.fromMap(Map<String, dynamic> map) => MessageTemplate(
        type: map['type'] ?? 'grading',
        content: map['content'] ?? '',
      );
}
