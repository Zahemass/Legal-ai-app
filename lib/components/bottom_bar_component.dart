import 'package:flutter/material.dart';
import 'dart:ui';

class BottomBarComponent extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabSelected;

  const BottomBarComponent({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double totalPadding = 24.0;
    final double availableWidth = screenWidth - totalPadding;
    final double tabWidth = availableWidth / 4;

    return Container(
      height: 80,
      child: Stack(
        children: [
          // 1. Background Blur Layer
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.95),
                  border: Border(
                    top: BorderSide(
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Sliding Spotlight Indicator
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuint,
            left: 12 + (tabWidth * selectedIndex),
            top: 10,
            child: Container(
              width: tabWidth,
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF3B82F6).withOpacity(0.2),
                      const Color(0xFF2563EB).withOpacity(0.1),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6). withOpacity(0.15),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Icons Row
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildNavItem(0, Icons.dashboard_rounded, "Home", tabWidth),
                  _buildNavItem(1, Icons.folder_rounded, "Cases", tabWidth),
                  _buildNavItem(2, Icons.description_rounded, "Docs", tabWidth),
                  _buildNavItem(3, Icons. person_rounded, "Profile", tabWidth),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, double width) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => onTabSelected(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: 80,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          tween: Tween(begin: 0.0, end: isSelected ?  1.0 : 0.0),
          builder: (context, value, child) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon with scale animation
                  Transform.scale(
                    scale: 1.0 + (0.15 * value),
                    child: Icon(
                      icon,
                      size: 24,
                      color: Color. lerp(
                        const Color(0xFF64748B),
                        const Color(0xFF60A5FA),
                        value,
                      ),
                    ),
                  ),

                  const SizedBox(height: 3),

                  // Text Label
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color.lerp(
                        const Color(0xFF64748B),
                        const Color(0xFFF1F5F9),
                        value,
                      ),
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 3),

                  // Glow dot indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isSelected ? 4 : 0,
                    height: isSelected ? 4 : 0,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.8),
                          blurRadius: 4,
                        )
                      ]
                          : [],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}