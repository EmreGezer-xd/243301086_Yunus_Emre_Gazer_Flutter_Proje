import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Hatayı çözen ana paket
import 'auth_page.dart';
import 'ana_sayfa.dart';

void main() async {
  // Flutter elementlerinin tarayıcıda güvenle başlatılmasını sağlar
  WidgetsFlutterBinding.ensureInitialized();

  // Kırmızı ekranı yok eden sihirli Supabase başlatıcı kod bloğu
  try {
    await Supabase.initialize(
      // Buradaki URL ve Anon Key kısımlarını kendi Supabase bilgilerine göre doldur dostum.
      // Eğer şu an hatırlamıyorsan auth_page.dart dosyasının içine bak, orada aynısı yazıyordur.
      url: 'https://eqpmomjaoqoxukzsrsbb.supabase.co',
      anonKey: 'sb_publishable_t6iZC7aek9yrCstLINLjgA_hEChYLHq',
    );
  } catch (e) {
    // Eğer çift başlatma hatası veya key eksikliği olursa uygulamanın çökmesini önler.
    debugPrint("Supabase zaten başlatılmış veya bir hata oluştu: $e");
  }

  runApp(const CareerCoachApp());
}

class CareerCoachApp extends StatelessWidget {
  const CareerCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kariyer Koçu Projesi',
      debugShowCheckedModeBanner: false,

      // Kurumsal Premium Tema Tasarımı
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A), // Gece Mavisi
          primary: const Color(0xFF1E3A8A),
          secondary: const Color(0xFF10B981), // Başarı Yeşili
          background: const Color(0xFFF8FAFC),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 2,
        ),
      ),

      // Uygulama senin Supabase entegreli giriş ekranınla açılacak
      home: const AuthPage(),

      routes: {
        '/auth': (context) => const AuthPage(),
        '/home': (context) => const AnaSayfa(),
      },
    );
  }
}