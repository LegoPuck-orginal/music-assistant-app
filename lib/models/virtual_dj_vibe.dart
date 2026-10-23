import 'package:flutter/material.dart';

enum DjVibeCategory {
  allTimeFavorites,
  rockClassics,
  forgottenGems,
  artistDiscoveries,
  partyVibes,
  lateNightChill,
}

class DjVibe {
  final DjVibeCategory category;
  final String title;
  final String subtitle;
  final String icon;
  final List<Color> gradient;
  final String introPrompt;

  const DjVibe({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.introPrompt,
  });

  static const List<DjVibe> allVibes = [
    DjVibe(
      category: DjVibeCategory.allTimeFavorites,
      title: 'Deine Allzeit-Favoriten',
      subtitle: 'Meistgehörte Songs aus deiner Mediathek',
      icon: '🔥',
      gradient: [Color(0xFFFF5C00), Color(0xFF191414)],
      introPrompt:
          'Hey {user}! Hier ist dein persönlicher DJ. Ich hab deine Allzeit-Favoriten aus dem Hörverlauf geladen – los geht\'s mit deinen absoluten Lieblings-Tracks!',
    ),
    DjVibe(
      category: DjVibeCategory.rockClassics,
      title: 'Rock & Energetisch',
      subtitle: 'Kräftige Riffs & legendäre Stimmen',
      icon: '🎸',
      gradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      introPrompt:
          'Jetzt drehen wir auf, {user}! Hier kommt ein handverlesener Rock-Block für dich. Boxen aufdrehen und abgehen!',
    ),
    DjVibe(
      category: DjVibeCategory.forgottenGems,
      title: 'Vergessene Schätze',
      subtitle: 'Früher geliebt, lange nicht gehört',
      icon: '⏳',
      gradient: [Color(0xFFFF512F), Color(0xFFDD2476)],
      introPrompt:
          'Lust auf etwas Nostalgie, {user}? Diese Songs hast du schon viel zu lange nicht mehr gehört. Lass uns alte Schätze wiederentdecken!',
    ),
    DjVibe(
      category: DjVibeCategory.artistDiscoveries,
      title: 'Künstler-Entdeckungen',
      subtitle: 'Frische Sounds passend zu deinem Geschmack',
      icon: '🚀',
      gradient: [Color(0xFF00c6ff), Color(0xFF0072ff)],
      introPrompt:
          'Zeit für neue Musik, {user}! Diese frischen Künstler passen perfekt zu deiner musikalischen DNA.',
    ),
    DjVibe(
      category: DjVibeCategory.partyVibes,
      title: 'Party & Gute Laune',
      subtitle: 'Mitreißende Beats & Feierlaune',
      icon: '🎉',
      gradient: [Color(0xFFFF8008), Color(0xFFFFC837)],
      introPrompt:
          'Bringen wir Energie in die Bude, {user}! Hier kommt ein mitreißender Party-Mix für maximale Stimmung!',
    ),
    DjVibe(
      category: DjVibeCategory.lateNightChill,
      title: 'Late Night Chill',
      subtitle: 'Ruhige Klänge zum Entspannen',
      icon: '🌙',
      gradient: [Color(0xFF0F2027), Color(0xFF2C5364)],
      introPrompt:
          'Späte Stunden, entspannte Töne. Hier ist dein Chill-Mix zum Zurücklehnen und Abschalten.',
    ),
  ];
}
