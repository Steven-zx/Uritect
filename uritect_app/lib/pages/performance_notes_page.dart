import 'package:flutter/material.dart';

class PerformanceNotesPage extends StatelessWidget {
  const PerformanceNotesPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Research performance and limits')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Text(
          'Corrected experimental classifier',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'For supervised research testing. The corrected model uses re-extracted features with the established LEU-to-GLU order from tip to handle. Its exploratory development evaluation was 79.92% individual-analyte accuracy and 13.56% all-ten accuracy on 118 test events. This changed subset is not directly comparable to the historical results below and does not establish independent phone or clinical performance. Older saved readings remain unverified.',
        ),
        SizedBox(height: 24),
        Text(
          'Historical development evaluation',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        Text(
          '82.52% individual-analyte accuracy (1,345 of 1,630 pad results).',
        ),
        SizedBox(height: 12),
        Text(
          '17.18% all-ten accuracy (28 of 163 scans had every category correct).',
        ),
        SizedBox(height: 12),
        Text(
          '19.17% all-ten accuracy among confidence-filtered scans in the cached-feature evaluation. This is not an end-to-end phone acceptance or retake rate.',
        ),
        SizedBox(height: 20),
        Text(
          'These measures concern semiquantitative strip categories, not UTI detection. Related captures crossed development partitions, and these results informed tuning. They do not establish independent performance of this app build.',
        ),
        SizedBox(height: 20),
        Text(
          'Model confidence describes agreement among nearby training examples. It is not a probability that the result is correct. Distance checks and image checks reject some unsupported inputs; they cannot prove that an image is authentic or that the strip was read correctly.',
        ),
        SizedBox(height: 20),
        Text(
          'The Bayesian output is a provisional literature-derived screening estimate. Expert content review is separate from statistical calibration. Female symptom/dipstick multiplication, ordered male likelihood-ratio branches and transported priors remain assumptions requiring statistical review and culture-confirmed outcome validation.',
        ),
        SizedBox(height: 20),
        Text(
          'This offline research prototype does not provide a diagnosis or a clinically validated Low/Moderate/High risk score. Follow the exact strip instructions and obtain qualified review. Serious symptoms need attention even when scanning fails.',
        ),
      ],
    ),
  );
}
