part of 'player_bar_bloc.dart';

@immutable
abstract class PlayerBarState {
  // تعريف الارتفاع كمتغير أساسي في الحالة لسهولة الوصول إليه في الواجهة
  final double height;

  const PlayerBarState({required this.height});
}

/// 1. الحالة الابتدائية عند فتح التطبيق
class PlayerBarInitial extends PlayerBarState {
  const PlayerBarInitial({super.height = 60.0});
}

/// 2. الحالة عندما يكون المشغل نشطاً (ظاهراً)
/// يتم تمرير الارتفاع ديناميكياً (مثلاً 60 أو 70) بناءً على نوع الحدث
class PlayerBarVisible extends PlayerBarState {
  const PlayerBarVisible({required super.height});
}

/// 3. الحالة عندما يتم إخفاء الشريط مؤقتاً
class PlayerBarHidden extends PlayerBarState {
  const PlayerBarHidden({super.height = 0.0});
}

/// 4. الحالة عند إغلاق المشغل تماماً
class PlayerBarClosed extends PlayerBarState {
  const PlayerBarClosed({super.height = 0.0});
}