class ReceiptBoundingBoxEntity {
  const ReceiptBoundingBoxEntity({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

class ReceiptWordEntity {
  const ReceiptWordEntity({
    required this.text,
    required this.normalizedText,
    required this.boundingBox,
    required this.readingOrder,
  });

  final String text;
  final String normalizedText;
  final ReceiptBoundingBoxEntity boundingBox;
  final int readingOrder;
}

class ReceiptLineEntity {
  const ReceiptLineEntity({
    required this.text,
    required this.normalizedText,
    required this.boundingBox,
    required this.readingOrder,
    required this.words,
  });

  final String text;
  final String normalizedText;
  final ReceiptBoundingBoxEntity boundingBox;
  final int readingOrder;
  final List<ReceiptWordEntity> words;
}

class ReceiptBlockEntity {
  const ReceiptBlockEntity({
    required this.text,
    required this.normalizedText,
    required this.boundingBox,
    required this.readingOrder,
    required this.lines,
  });

  final String text;
  final String normalizedText;
  final ReceiptBoundingBoxEntity boundingBox;
  final int readingOrder;
  final List<ReceiptLineEntity> lines;
}

class ReceiptDocumentEntity {
  const ReceiptDocumentEntity({
    required this.blocks,
    required this.text,
    required this.normalizedText,
    required this.pageWidth,
    required this.pageHeight,
  });

  final List<ReceiptBlockEntity> blocks;
  final String text;
  final String normalizedText;
  final double pageWidth;
  final double pageHeight;

  List<ReceiptLineEntity> get lines => [
    for (final block in blocks) ...block.lines,
  ];
}
