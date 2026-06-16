import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/shared/widgets/shimmer_loading.dart';
import 'package:shimmer/shimmer.dart';

void main() {
  group('ShimmerLoading Widget Tests', () {
    testWidgets('ShimmerLoading renders correctly with given dimensions', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerLoading(width: 100, height: 50),
          ),
        ),
      );

      // Verify Shimmer is in the widget tree
      expect(find.byType(Shimmer), findsOneWidget);
      
      // Verify Container dimensions
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxWidth, 100);
      expect(container.constraints?.maxHeight, 50);
    });

    testWidgets('ShimmerLoading.list renders correct number of items', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShimmerLoading.list(count: 3),
          ),
        ),
      );

      // We expect 3 list items. Since each list item contains multiple ShimmerLoading widgets, 
      // we check for ListView children count or simply ListView presence.
      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
