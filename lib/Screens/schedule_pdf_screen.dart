import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class SchedulePdfScreen extends StatelessWidget {
  final String url;
  const SchedulePdfScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Program Schedule")),
      body: url.isEmpty
          ? const Center(child: Text("Schedule not available"))
          : SfPdfViewer.network(url),
    );
  }
}
