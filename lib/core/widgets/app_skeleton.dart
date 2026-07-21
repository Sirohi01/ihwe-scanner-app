import 'package:flutter/material.dart';

class AppSkeleton extends StatefulWidget {
  const AppSkeleton({super.key, required this.child});
  final Widget child;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 950))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (_, child) => Opacity(
          opacity: .48 + (controller.value * .34),
          child: child,
        ),
        child: IgnorePointer(child: widget.child),
      );
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox(
      {super.key, this.width, required this.height, this.radius = 12});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFDCE5EC),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({super.key, this.count = 7, this.padding});
  final int count;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => AppSkeleton(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: padding ?? const EdgeInsets.fromLTRB(18, 8, 18, 90),
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, __) => Container(
            height: 68,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFE6ECF1))),
            child: const Row(children: [
              SkeletonBox(width: 42, height: 42, radius: 12),
              SizedBox(width: 11),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SkeletonBox(width: 150, height: 11, radius: 5),
                      SizedBox(height: 8),
                      SkeletonBox(width: 105, height: 8, radius: 4),
                    ]),
              ),
              SkeletonBox(width: 38, height: 10, radius: 5),
            ]),
          ),
        ),
      );
}

class AppProfileSkeleton extends StatelessWidget {
  const AppProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) => AppSkeleton(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            Container(
              height: 205,
              decoration: BoxDecoration(
                  color: const Color(0xFFD6E1E7),
                  borderRadius: BorderRadius.circular(22)),
              child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SkeletonBox(width: 88, height: 98, radius: 18),
                    SizedBox(height: 12),
                    SkeletonBox(width: 150, height: 14, radius: 6),
                    SizedBox(height: 8),
                    SkeletonBox(width: 95, height: 9, radius: 5),
                  ]),
            ),
            const SizedBox(height: 11),
            ...List.generate(
                3,
                (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 9),
                      child: SkeletonBox(height: 68, radius: 15),
                    )),
          ],
        ),
      );
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => AppSkeleton(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SkeletonBox(width: 92, height: 10, radius: 5),
            const SizedBox(height: 9),
            const SkeletonBox(height: 34, radius: 17),
            const SizedBox(height: 12),
            const Row(children: [
              Expanded(child: SkeletonBox(height: 78, radius: 15)),
              SizedBox(width: 8),
              Expanded(child: SkeletonBox(height: 78, radius: 15)),
            ]),
            const SizedBox(height: 9),
            const SkeletonBox(height: 62, radius: 14),
            const SizedBox(height: 12),
            const Row(children: [
              Expanded(child: SkeletonBox(height: 72, radius: 14)),
              SizedBox(width: 7),
              Expanded(child: SkeletonBox(height: 72, radius: 14)),
              SizedBox(width: 7),
              Expanded(child: SkeletonBox(height: 72, radius: 14)),
            ]),
            const SizedBox(height: 14),
            ...List.generate(
                4,
                (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 7),
                      child: SkeletonBox(height: 58, radius: 14),
                    )),
          ]),
        ),
      );
}
