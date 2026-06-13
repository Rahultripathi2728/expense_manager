import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (var file in files) {
    var content = file.readAsStringSync();
    if (content.contains('AppColors.')) {
      // Remove 'const ' in lines that have AppColors
      // We will match "const " when followed by something that eventually has AppColors. on the same line
      // Actually, a simple text replace is risky if it removes const from other things.
      // Let's do it safely:
      // Replace `const Color` with `Color` (since some use const Color(..))
      // Replace `const Widget(` where Widget is something containing AppColors.
      // A better way: just run `flutter fix --apply` or remove all `const ` globally in the file for specific widgets: `const Icon`, `const Text`, `const EdgeInsets`, etc? No, `AppColors` is a color.
      // Let's just use `sed` equivalent in dart:
      var newContent = content.replaceAll(RegExp(r'const\s+(?=[A-Z][a-zA-Z0-9_]*\([^)]*AppColors\.)'), '');
      if (newContent != content) {
        file.writeAsStringSync(newContent);
      }
    }
  }
}
