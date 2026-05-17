import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ana_sayfa.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final _emailController = TextEditingController();
  final _sifreController = TextEditingController();
  final _adController = TextEditingController();
  final _soyadController = TextEditingController();

  String _secilenRol = "Öğrenci"; // Varsayılan kayıt rolü
  bool _isLogin = true; // Giriş ekranı mı kayıt ekranı mı kontrolü
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _sifreController.dispose();
    _adController.dispose();
    _soyadController.dispose();
    super.dispose();
  }

  void _mesajGoster(String mesaj, {required bool durum}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(durum ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(mesaj, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
          ],
        ),
        backgroundColor: durum ? const Color(0xFF059669) : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        elevation: 4,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _authIslemi() async {
    final email = _emailController.text.trim();
    final sifre = _sifreController.text.trim();
    final ad = _adController.text.trim();
    final soyad = _soyadController.text.trim();

    if (email.isEmpty || sifre.isEmpty) {
      _mesajGoster("Lütfen gerekli tüm alanları doldurun.", durum: false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // --- PRO SİSTEM GİRİŞ MOTORU ---
        final response = await _supabase.auth.signInWithPassword(email: email, password: sifre);
        if (response.user != null) {
          _mesajGoster("Başarıyla giriş yapıldı. Portala aktarılıyorsunuz...", durum: true);
          if (mounted) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const AnaSayfa()));
          }
        }
      } else {
        // --- PRO SİSTEM KAYIT MOTORU ---
        if (ad.isEmpty || soyad.isEmpty) {
          _mesajGoster("Lütfen adınızı ve soyadınızı girin.", durum: false);
          setState(() => _isLoading = false);
          return;
        }

        final response = await _supabase.auth.signUp(email: email, password: sifre);

        if (response.user != null) {
          // Kullanıcı kaydı başarılı olunca profil tablosuna rol ve isim bilgilerini yazıyoruz
          await _supabase.from('profiles').insert({
            'id': response.user!.id,
            'ad': ad,
            'soyad': soyad,
            'rol': _secilenRol,
          });

          _mesajGoster("Hesabınız başarıyla oluşturuldu! Giriş yapabilirsiniz.", durum: true);
          setState(() {
            _isLogin = true;
            _adController.clear();
            _soyadController.clear();
          });
        }
      }
    } catch (e) {
      _mesajGoster("Kimlik doğrulama hatası: ${e.toString()}", durum: false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- MODEL RESMİNDEKİ PREMIUM INPUT DEKORATÖRÜ ---
  InputDecoration _authInputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, color: const Color(0xFF3F51B5), size: 20),
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: const BorderSide(color: Colors.white24, width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: const BorderSide(color: Color(0xFF3F51B5), width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // --- GEÇİŞLİ PREMIUM GRADIENT ARKA PLAN ---
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF3F51B5), // Üst alan: Asil Indigo
              Color(0xFF1E1B4B), // Orta alan: Gece Mavisi
              Color(0xFF0F172A), // Alt alan: Derin Koyu Slate
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- 🧠 CANLI KOÇLUK / MENTORLUK SİMGESİ ALANI ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00B0FF).withOpacity(0.2),
                          blurRadius: 15,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: const Icon(Icons.psychology_rounded, size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isLogin ? "Kariyer Koçu Giriş" : "Koçluk Ailesine Katıl",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLogin ? "Geleceğini planlamak için oturum açın" : "Yeni bir kariyer profili oluşturun",
                    style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 32),

                  // --- PREMIUM GİRİŞ KART YAPISI ---
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 25, offset: const Offset(0, 12))
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          if (!_isLogin) ...[
                            TextField(controller: _adController, decoration: _authInputDecoration(label: 'Adınız', icon: Icons.person_outline_rounded)),
                            const SizedBox(height: 14),
                            TextField(controller: _soyadController, decoration: _authInputDecoration(label: 'Soyadınız', icon: Icons.person_pin_rounded)),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              value: _secilenRol,
                              dropdownColor: Colors.white,
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w500),
                              decoration: _authInputDecoration(label: 'Sistem Rolü', icon: Icons.assignment_ind_rounded),
                              items: ["Öğrenci", "Hoca"].map((rol) => DropdownMenuItem(value: rol, child: Text(rol))).toList(),
                              onChanged: (val) { if (val != null) setState(() => _secilenRol = val); },
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: _authInputDecoration(label: 'E-posta Adresi', icon: Icons.alternate_email_rounded)),
                          const SizedBox(height: 14),
                          TextField(controller: _sifreController, obscureText: true, decoration: _authInputDecoration(label: 'Şifre', icon: Icons.lock_outline_rounded)),
                          const SizedBox(height: 24),

                          // --- GİRİŞ / KAYIT BUTONU ---
                          _isLoading
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFF3F51B5)))
                              : Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [BoxShadow(color: const Color(0xFF3F51B5).withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 6))],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                backgroundColor: const Color(0xFF3F51B5),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                              ),
                              onPressed: _authIslemi,
                              child: Text(_isLogin ? "Giriş Yap" : "Hesabı Oluştur", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // --- ŞEFFAF VE OVAL ALT DEĞİŞTİRME BUTONU ---
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin ? "Hesabınız yok mu? Kayıt Olun" : "Zaten üye misiniz? Giriş Yapın",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}