import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_page.dart';

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  int _secilenIndeks = 4; // Doğrudan Profil sekmesi açık başlar
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- GÖREVLER SEKLESİ CONTROLLER YAPILARI ---
  final _gorevBaslikController = TextEditingController();
  final _gorevAciklamaController = TextEditingController();
  String _secilenDurum = "Yapılacak";

  // --- TOPLANTI & GÖRÜŞME SEKLESİ CONTROLLER YAPILARI ---
  final _toplantiBaslikController = TextEditingController();
  final _gorusmeNotController = TextEditingController();
  DateTime? _secilenTarih;
  TimeOfDay? _secilenSaat;

  // ÇOKLU VE TEKLİ SEÇİM LİSTELERİ
  List<String> _secilenOgrenciIdleri = []; // Hocanın toplantı için çoklu seçimi
  String? _secilenTekOgrenciId = null; // Hocanın görüşme için tekli seçimi
  String? _secilenHocaId = null; // Öğrencinin görüşme talep ederken seçeceği hoca

  // --- NOTLAR SEKLESİ CONTROLLER YAPILARI ---
  final _notBaslikController = TextEditingController();
  final _notIcerikController = TextEditingController();

  // --- HOCA GÖREV ATAMA POP-UP CONTROLLER YAPILARI ---
  final _hocaGorevBaslikController = TextEditingController();
  final _hocaGorevAciklamaController = TextEditingController();

  // --- ÖĞRENCİ GÖREV TESLİM KANITI CONTROLLER YAPISI ---
  final _teslimKanitController = TextEditingController();

  bool _isSaving = false;

  // --- GİRİŞ EKRANIYLA UYUMLU PREMIUM KOÇLUK RENK PALETİ ---
  final Color primaryColor = const Color(0xFF3F51B5); // Giriş ekranındaki asil Indigo
  final Color secondaryColor = const Color(0xFF00B0FF); // Canlı Parlak Mavi
  final Color backgroundColor = const Color(0xFFF8FAFC); // Soft Slate Arka Plan
  final Color cardColor = Colors.white;
  final Color darkTextColor = const Color(0xFF0F172A); // Koyu Slate Yazı
  final Color mutedTextColor = const Color(0xFF64748B); // Yumuşak Gri Yazı

  @override
  void dispose() {
    _gorevBaslikController.dispose();
    _gorevAciklamaController.dispose();
    _toplantiBaslikController.dispose();
    _gorusmeNotController.dispose();
    _notBaslikController.dispose();
    _notIcerikController.dispose();
    _hocaGorevBaslikController.dispose();
    _hocaGorevAciklamaController.dispose();
    _teslimKanitController.dispose();
    super.dispose();
  }

  // --- BİLDİRİM VE MESAJ MOTORU ---
  void _mesajGoster(String mesaj, {required bool durum}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(durum ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(mesaj, style: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w500, fontSize: 13))),
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

  // --- TARİH VE SAAT SEÇİCİ YARDIMCILARI ---
  Future<void> _tarihSec(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primaryColor, onPrimary: Colors.white, onSurface: darkTextColor),
            textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: primaryColor)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _secilenTarih) {
      setState(() { _secilenTarih = picked; });
    }
  }

  Future<void> _saatSec(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primaryColor, onPrimary: Colors.white, onSurface: darkTextColor),
            textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: primaryColor)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _secilenSaat) {
      setState(() { _secilenSaat = picked; });
    }
  }

  void _fotografSec() {
    _mesajGoster("Profil fotoğrafı güncelleme özelliği yakında aktif olacak.", durum: true);
  }

  // --- SUPABASE VERİ AKIŞLARI (STREAM & FUTURE) ---
  Future<Map<String, dynamic>?> _profilVerisiniGetir() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    try {
      return await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
    } catch (e) {
      return null;
    }
  }

  Stream<List<Map<String, dynamic>>> _tumOgrencileriDinle() {
    return _supabase.from('profiles').stream(primaryKey: ['id']).map((maps) {
      return maps.where((element) => element['rol'] == 'Öğrenci').toList();
    });
  }

  Stream<List<Map<String, dynamic>>> _tumHocalariDinle() {
    return _supabase.from('profiles').stream(primaryKey: ['id']).map((maps) {
      return maps.where((element) => element['rol'] == 'Hoca').toList();
    });
  }

  Stream<List<Map<String, dynamic>>> _ogrenciGorevleriniDinle() {
    final user = _supabase.auth.currentUser;
    return _supabase.from('coaching_tasks').stream(primaryKey: ['id']).map((maps) {
      return maps.where((element) => element['user_id'] == user?.id).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> _hocaIcinOgrenciGorevleriniDinle(String ogrenciId) {
    return _supabase.from('coaching_tasks').stream(primaryKey: ['id']).map((maps) {
      return maps.where((element) => element['user_id'] == ogrenciId).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> _toplantilariDinle(String tip) {
    final user = _supabase.auth.currentUser;
    return _supabase.from('meetings').stream(primaryKey: ['id']).map((maps) {
      return maps.where((element) => element['type'] == tip && (element['user_id'] == user?.id || element['hoca_id'] == user?.id)).toList();
    }).asyncMap((filtrelenmis) async {
      List<Map<String, dynamic>> zenginlestirilmisListe = [];
      for (var toplanti in filtrelenmis) {
        final kopyalanan = Map<String, dynamic>.from(toplanti);
        try {
          if (kopyalanan['hoca_id'] != null) {
            final hocaProfil = await _supabase.from('profiles').select('ad, soyad').eq('id', kopyalanan['hoca_id']).maybeSingle();
            if (hocaProfil != null) {
              kopyalanan['hoca_ad_soyad'] = "${hocaProfil['ad'] ?? ''} ${hocaProfil['soyad'] ?? ''}";
            }
          }
          if (kopyalanan['user_id'] != null) {
            final ogrenciProfil = await _supabase.from('profiles').select('ad, soyad').eq('id', kopyalanan['user_id']).maybeSingle();
            if (ogrenciProfil != null) {
              kopyalanan['ogrenci_ad_soyad'] = "${ogrenciProfil['ad'] ?? ''} ${ogrenciProfil['soyad'] ?? ''}";
            }
          }
        } catch (_) {}
        zenginlestirilmisListe.add(kopyalanan);
      }
      return zenginlestirilmisListe;
    });
  }

  Stream<List<Map<String, dynamic>>> _notlariDinle() {
    final user = _supabase.auth.currentUser;
    return _supabase.from('coaching_notes').stream(primaryKey: ['id']).map((maps) {
      return maps.where((element) => element['user_id'] == user?.id).toList();
    });
  }

  // --- İŞLEM FONKSİYONLARI ---
  Future<void> _gorevEkle() async {
    final user = _supabase.auth.currentUser;
    final baslik = _gorevBaslikController.text.trim();
    final aciklama = _gorevAciklamaController.text.trim();

    if (baslik.isEmpty || user == null) return;

    setState(() => _isSaving = true);
    try {
      await _supabase.from('coaching_tasks').insert({
        'title': baslik,
        'description': aciklama.isNotEmpty ? aciklama : null,
        'status': _secilenDurum,
        'user_id': user.id,
      });
      _mesajGoster("Görev başarıyla eklendi!", durum: true);
      _gorevBaslikController.clear();
      _gorevAciklamaController.clear();
    } catch (e) {
      _mesajGoster("Hata: $e", durum: false);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _hocaGorevAta(String ogrenciId, String ogrenciAdSoyad) async {
    final hoca = _supabase.auth.currentUser;
    final baslik = _hocaGorevBaslikController.text.trim();
    final aciklama = _hocaGorevAciklamaController.text.trim();

    if (baslik.isEmpty || hoca == null) {
      _mesajGoster("Görev başlığı boş bırakılamaz!", durum: false);
      return;
    }

    try {
      await _supabase.from('coaching_tasks').insert({
        'title': baslik,
        'description': aciklama.isNotEmpty ? aciklama : null,
        'status': 'Yapılacak',
        'user_id': ogrenciId,
        'hoca_id': hoca.id,
      });
      _mesajGoster("Öğrenciye görev başarıyla atandı!", durum: true);
      _hocaGorevBaslikController.clear();
      _hocaGorevAciklamaController.clear();
    } catch (e) {
      _mesajGoster("Hata: $e", durum: false);
    }
  }

  Future<void> _gorevDurumunuGuncelle(int gorevId, String yeniDurum) async {
    try {
      await _supabase.from('coaching_tasks').update({'status': yeniDurum}).eq('id', gorevId);
      _mesajGoster("Görev durumu güncellendi!", durum: true);
    } catch (e) {
      _mesajGoster("Hata: $e", durum: false);
    }
  }

  Future<void> _goreviKanitlaVeTamamla(int gorevId) async {
    final kanitMetni = _teslimKanitController.text.trim();
    if (kanitMetni.isEmpty) {
      _mesajGoster("Lütfen teslim kanıtı veya açıklama girin.", durum: false);
      return;
    }

    try {
      await _supabase.from('coaching_tasks').update({
        'status': 'Tamamlandı',
        'submission_proof': kanitMetni,
      }).eq('id', gorevId);
      _mesajGoster("Görev kanıtıyla birlikte başarıyla teslim edildi!", durum: true);
      _teslimKanitController.clear();
    } catch (e) {
      _mesajGoster("Teslim hatası: $e", durum: false);
    }
  }

  Future<void> _randevuAyarla(String randevuTipi, String userRol) async {
    final currentKullanici = _supabase.auth.currentUser;
    final baslik = randevuTipi == 'Toplantı' ? _toplantiBaslikController.text.trim() : "Birebir Görüşme";
    final not = _gorusmeNotController.text.trim();

    if (randevuTipi == 'Toplantı' && baslik.isEmpty) {
      _mesajGoster("Lütfen toplantı başlığını girin.", durum: false);
      return;
    }
    if (_secilenTarih == null || _secilenSaat == null || currentKullanici == null) {
      _mesajGoster("Lütfen tarih ve saat seçimi yapın.", durum: false);
      return;
    }

    if (userRol == 'Hoca') {
      if (randevuTipi == 'Toplantı' && _secilenOgrenciIdleri.length < 2) {
        _mesajGoster("Toplantılar grup çalışmasıdır, en az 2 öğrenci seçilmelidir!", durum: false);
        return;
      }
      if (randevuTipi == 'Görüşme' && _secilenTekOgrenciId == null) {
        _mesajGoster("Lütfen görüşme yapacağınız öğrenciyi seçin.", durum: false);
        return;
      }
    } else {
      if (randevuTipi == 'Görüşme' && _secilenHocaId == null) {
        _mesajGoster("Lütfen görüşme talep edeceğiniz hocanızı seçin.", durum: false);
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final tamTarih = DateTime(_secilenTarih!.year, _secilenTarih!.month, _secilenTarih!.day, _secilenSaat!.hour, _secilenSaat!.minute);

      if (userRol == 'Hoca' && randevuTipi == 'Toplantı') {
        for (String ogrenciId in _secilenOgrenciIdleri) {
          await _supabase.from('meetings').insert({
            'title': baslik,
            'description': not.isNotEmpty ? not : "Grup Toplantısı Katılımcısı",
            'meeting_date': tamTarih.toIso8601String(),
            'type': 'Toplantı',
            'hoca_id': currentKullanici.id.toString(),
            'user_id': ogrenciId.toString(),
          });
        }
      } else {
        final Map<String, dynamic> insertData = {
          'title': baslik,
          'description': not.isNotEmpty ? not : null,
          'meeting_date': tamTarih.toIso8601String(),
          'type': randevuTipi,
        };

        if (userRol == 'Hoca') {
          insertData['hoca_id'] = currentKullanici.id.toString();
          insertData['user_id'] = _secilenTekOgrenciId.toString();
        } else {
          insertData['user_id'] = currentKullanici.id.toString();
          insertData['hoca_id'] = _secilenHocaId.toString();
        }
        await _supabase.from('meetings').insert(insertData);
      }

      _mesajGoster("$randevuTipi başarıyla planlandı!", durum: true);
      _toplantiBaslikController.clear();
      _gorusmeNotController.clear();
      setState(() {
        _secilenTarih = null;
        _secilenSaat = null;
        _secilenOgrenciIdleri.clear();
        _secilenTekOgrenciId = null;
        _secilenHocaId = null;
      });
    } catch (e) {
      _mesajGoster("Planlama hatası: $e", durum: false);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _notEkle() async {
    final user = _supabase.auth.currentUser;
    final baslik = _notBaslikController.text.trim();
    final icerik = _notIcerikController.text.trim();

    if (baslik.isEmpty || icerik.isEmpty || user == null) return;

    setState(() => _isSaving = true);
    try {
      await _supabase.from('coaching_notes').insert({'title': baslik, 'content': icerik, 'user_id': user.id});
      _mesajGoster("Not başarıyla kaydedildi!", durum: true);
      _notBaslikController.clear();
      _notIcerikController.clear();
    } catch (e) {
      _mesajGoster("Hata: $e", durum: false);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _notSil(int id) async {
    try {
      await _supabase.from('coaching_notes').delete().eq('id', id);
      _mesajGoster("Not başarıyla silindi.", durum: true);
    } catch (e) {
      _mesajGoster("Silme hatası: $e", durum: false);
    }
  }

  // --- INPUT TASARIM DEKORATÖRÜ ---
  InputDecoration _modernInputDecoration({required String label, required IconData icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: const BorderSide(color: Colors.white24, width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide(color: primaryColor, width: 1.5)),
    );
  }

  // --- MODERN SEKSİYON BAŞLIĞI ---
  Widget _buildSectionHeader({required String title, required String subtitle, required IconData icon}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: primaryColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkTextColor, letterSpacing: 0.3)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: mutedTextColor)),
            ],
          ),
        ),
      ],
    );
  }

  // --- PREMIUM INDIGO BUTTON DEKORATÖRÜ ---
  Widget _buildVistaButton({required String label, required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
      ),
    );
  }

  // --- REUSABLE CAM KART TASARIMI ---
  Widget _buildGlassCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  // --- POPUP DIALOGS ---
  void _hocaGorevAtamaPenceresiAc(String ogrenciId, String ogrenciAdSoyad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              _buildSectionHeader(title: "Görev Atama Portalı", subtitle: "$ogrenciAdSoyad öğrencisi için yeni bir hedef belirleyin.", icon: Icons.assignment_turned_in_rounded),
              const SizedBox(height: 20),
              TextField(controller: _hocaGorevBaslikController, decoration: _modernInputDecoration(label: 'Görev Başlığı', icon: Icons.assignment_rounded)),
              const SizedBox(height: 14),
              TextField(controller: _hocaGorevAciklamaController, maxLines: 3, decoration: _modernInputDecoration(label: 'Görev Açıklaması / Detaylar', icon: Icons.description_rounded)),
              const SizedBox(height: 24),
              _buildVistaButton(
                  label: "Görevi Kesinleştir ve Ata",
                  icon: Icons.send_rounded,
                  onPressed: () { _hocaGorevAta(ogrenciId, ogrenciAdSoyad); Navigator.pop(context); }
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _hocaGorevIncelemePenceresiAc(String ogrenciId, String ogrenciAdSoyad) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            _buildSectionHeader(title: "Performans Takip Paneli", subtitle: "$ogrenciAdSoyad öğrencisinin güncel hedefleri.", icon: Icons.analytics_rounded),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _hocaIcinOgrenciGorevleriniDinle(ogrenciId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final gorevler = snapshot.data ?? [];
                  if (gorevler.isEmpty) {
                    return Center(child: Text("Bu öğrenciye ait atanmış görev bulunamadı.", style: TextStyle(color: mutedTextColor, fontSize: 13)));
                  }
                  return ListView.builder(
                    itemCount: gorevler.length,
                    itemBuilder: (context, index) {
                      final g = gorevler[index];
                      final durum = g['status'] ?? 'Yapılacak';
                      final kanit = g['submission_proof'] ?? 'Kanıt henüz yüklenmemiş.';
                      Color statusColor = Colors.orange;
                      if (durum == 'Tamamlandı') statusColor = const Color(0xFF10B981);
                      if (durum == 'Sürüyor') statusColor = secondaryColor;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(g['title'] ?? 'Başlıksız', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: darkTextColor)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text(g['description'] ?? 'Açıklama yok.', style: TextStyle(color: mutedTextColor, fontSize: 13)),
                              const SizedBox(height: 10),
                              Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)), child: Text("Çalışma Notu: $kanit", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blueGrey))),
                            ],
                          ),
                          trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(durum, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold))),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _ogrenciKanitTeslimPenceresiAc(int gorevId, String gorevBaslik) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            _buildSectionHeader(title: "Görevi Sonuçlandır", subtitle: "$gorevBaslik görevi için yaptığınız çalışmayı açıklayın.", icon: Icons.cloud_done_rounded),
            const SizedBox(height: 16),
            TextField(controller: _teslimKanitController, maxLines: 3, decoration: _modernInputDecoration(label: 'Teslim Kanıtı / Çalışma Notu', icon: Icons.assignment_turned_in_rounded, hint: 'Github linki veya kısa açıklama yazın...')),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)), elevation: 0),
                icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 18),
                label: const Text("Kanıtı Gönder ve Tamamla", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                onPressed: () { _goreviKanitlaVeTamamla(gorevId); Navigator.pop(context); },
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // --- SEKMESEL GÖRÜNÜM TASARIMLARI ---

  Widget _gorevSekmesi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGlassCard(
            children: [
              _buildSectionHeader(title: "Yeni Koçluk Görevi Tanımla", subtitle: "Kariyer hedeflerin için yapılması gerekenleri listele.", icon: Icons.playlist_add_rounded),
              const SizedBox(height: 20),
              TextField(controller: _gorevBaslikController, decoration: _modernInputDecoration(label: 'Görev Başlığı', icon: Icons.assignment_rounded)),
              const SizedBox(height: 14),
              TextField(controller: _gorevAciklamaController, decoration: _modernInputDecoration(label: 'Görev Açıklaması', icon: Icons.description_rounded)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _secilenDurum,
                style: TextStyle(color: darkTextColor, fontSize: 14, fontWeight: FontWeight.w500),
                dropdownColor: Colors.white,
                decoration: _modernInputDecoration(label: 'Görev Durumu', icon: Icons.hourglass_empty_rounded),
                items: ["Yapılacak", "Sürüyor", "Tamamlandı"].map((durum) => DropdownMenuItem(value: durum, child: Text(durum))).toList(),
                onChanged: (yeniDeger) { if (yeniDeger != null) setState(() => _secilenDurum = yeniDeger); },
              ),
              const SizedBox(height: 22),
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : _buildVistaButton(label: "Görevi Portala Ekle", icon: Icons.add_rounded, onPressed: _gorevEkle),
            ],
          ),
          const SizedBox(height: 28),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: const Text("Güncel Çalışma Planın", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.3))),
          const SizedBox(height: 12),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _ogrenciGorevleriniDinle(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final gorevler = snapshot.data ?? [];
              if (gorevler.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(28), width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Text("Henüz bir çalışma planı eklenmedi.", style: TextStyle(color: mutedTextColor, fontSize: 13), textAlign: TextAlign.center),
                );
              }
              return ListView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: gorevler.length,
                itemBuilder: (context, index) {
                  final gorev = gorevler[index];
                  final gorevId = gorev['id'] as int;
                  final title = gorev['title'] ?? 'Başlıksız';
                  final durumStr = gorev['status'] ?? 'Yapılacak';
                  Color renk = Colors.orange;
                  Widget aksiyonButonu = const SizedBox();

                  if (durumStr == 'Yapılacak') {
                    renk = Colors.orange;
                    aksiyonButonu = IconButton(icon: Icon(Icons.play_circle_fill_rounded, size: 32, color: secondaryColor), onPressed: () => _gorevDurumunuGuncelle(gorevId, 'Sürüyor'));
                  } else if (durumStr == 'Sürüyor') {
                    renk = secondaryColor;
                    aksiyonButonu = IconButton(icon: const Icon(Icons.check_circle_rounded, size: 32, color: Color(0xFF10B981)), onPressed: () => _ogrenciKanitTeslimPenceresiAc(gorevId, title));
                  } else if (durumStr == 'Tamamlandı') {
                    renk = const Color(0xFF10B981);
                    aksiyonButonu = const Icon(Icons.stars_rounded, color: Colors.amber, size: 26);
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white30)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(backgroundColor: renk.withOpacity(0.08), radius: 24, child: Icon(Icons.assignment_rounded, color: renk, size: 20)),
                      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: darkTextColor)),
                      subtitle: Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(gorev['description'] ?? 'Detay belirtilmemiş.', style: TextStyle(color: mutedTextColor, fontSize: 12))),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: renk.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(durumStr, style: TextStyle(color: renk, fontSize: 10, fontWeight: FontWeight.bold))), const SizedBox(width: 8), aksiyonButonu]),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _toplantiSekmesi(String userRol) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (userRol == 'Hoca') ...[
            _buildGlassCard(
              children: [
                Row(
                  children: [
                    Icon(Icons.video_call_rounded, color: primaryColor, size: 26),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        "🎯 Toplantı Organize Et (Grup Katılımı)",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text("Toplantılar grup çalışması mantığındadır ve en az 2 öğrenci seçilmelidir.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                const Text("👥 Katılacak Öğrencileri Seçin:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _tumOgrencileriDinle(),
                    builder: (context, snapshot) {
                      final ogrenciler = snapshot.data ?? [];
                      if (ogrenciler.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("Kayıtlı öğrenci bulunamadı.")));
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: ogrenciler.length,
                        itemBuilder: (context, index) {
                          final o = ogrenciler[index];
                          final idStr = o['id'].toString();
                          final adSoyad = "${o['ad'] ?? ''} ${o['soyad'] ?? ''}";
                          final isChecked = _secilenOgrenciIdleri.contains(idStr);
                          return CheckboxListTile(
                            title: Text(adSoyad, style: TextStyle(fontSize: 14, color: darkTextColor)),
                            value: isChecked,
                            activeColor: primaryColor,
                            checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) { _secilenOgrenciIdleri.add(idStr); } else { _secilenOgrenciIdleri.remove(idStr); }
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Text("Seçilen Öğrenci Sayısı: ${_secilenOgrenciIdleri.length}", style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 13)),
                const SizedBox(height: 16),
                TextField(controller: _toplantiBaslikController, decoration: _modernInputDecoration(label: 'Toplantı Konusu / Grup İsmi', icon: Icons.title_rounded)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)), side: BorderSide(color: Colors.grey.shade300)), icon: Icon(Icons.calendar_month_rounded, color: primaryColor, size: 18), label: Text(_secilenTarih == null ? "Tarih Seç" : _secilenTarih!.toString().substring(0, 10), style: TextStyle(color: darkTextColor, fontSize: 13)), onPressed: () => _tarihSec(context))),
                    const SizedBox(width: 12),
                    Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)), side: BorderSide(color: Colors.grey.shade300)), icon: Icon(Icons.access_time_rounded, color: primaryColor, size: 18), label: Text(_secilenSaat == null ? "Saat Seç" : _secilenSaat!.format(context), style: TextStyle(color: darkTextColor, fontSize: 13)), onPressed: () => _saatSec(context))),
                  ],
                ),
                const SizedBox(height: 16),
                _isSaving ? const Center(child: CircularProgressIndicator()) : _buildVistaButton(label: "Grup Toplantısını Planla", icon: Icons.bolt_rounded, onPressed: () => _randevuAyarla('Toplantı', userRol)),
              ],
            ),
            const SizedBox(height: 24),
          ],
          const Padding(padding: EdgeInsets.symmetric(horizontal: 4.0), child: Text("Planlanmış Canlı Toplantı Seansları", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.3))),
          const SizedBox(height: 12),
          _randevuListesiOlustur('Toplantı'),
        ],
      ),
    );
  }

  Widget _gorusmeSekmesi(String userRol) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGlassCard(
            children: [
              _buildSectionHeader(
                  title: userRol == 'Hoca' ? "Birebir Danışmanlık Seansı" : "Koçluk Görüşme Talebi",
                  subtitle: userRol == 'Hoca' ? "Öğrencinize özel takvim planı oluşturun." : "Kariyer danışmanınızdan uygun bir saat talep edin.",
                  icon: Icons.forum_rounded
              ),
              const SizedBox(height: 18),
              if (userRol == 'Hoca') ...[
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _tumOgrencileriDinle(),
                  builder: (context, snapshot) {
                    final ogrenciler = snapshot.data ?? [];
                    List<DropdownMenuItem<String>> menuItems = [];
                    for (var o in ogrenciler) {
                      final idStr = o['id']?.toString();
                      if (idStr != null) {
                        menuItems.add(DropdownMenuItem(value: idStr, child: Text("${o['ad']} ${o['soyad']}", style: const TextStyle(fontSize: 14))));
                      }
                    }
                    return DropdownButtonFormField<String>(value: _secilenTekOgrenciId, dropdownColor: Colors.white, decoration: _modernInputDecoration(label: 'Görüşme Yapılacak Öğrenci', icon: Icons.school_rounded), items: menuItems, onChanged: (yeniOgrId) => setState(() => _secilenTekOgrenciId = yeniOgrId));
                  },
                ),
              ] else ...[
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _tumHocalariDinle(),
                  builder: (context, snapshot) {
                    final hocalar = snapshot.data ?? [];
                    List<DropdownMenuItem<String>> menuItems = [];
                    for (var h in hocalar) {
                      final idStr = h['id']?.toString();
                      if (idStr != null) {
                        menuItems.add(DropdownMenuItem(value: idStr, child: Text("Koç ${h['ad']} ${h['soyad']}", style: const TextStyle(fontSize: 14))));
                      }
                    }
                    return DropdownButtonFormField<String>(value: _secilenHocaId, dropdownColor: Colors.white, decoration: _modernInputDecoration(label: 'Eğitim Koçu Seçin', icon: Icons.person_pin_rounded), items: menuItems, onChanged: (yeniHocaId) => setState(() => _secilenHocaId = yeniHocaId));
                  },
                ),
              ],
              const SizedBox(height: 14),
              TextField(controller: _gorusmeNotController, maxLines: 2, decoration: _modernInputDecoration(label: 'Görüşme Notu / Gündem Konusu', icon: Icons.chat_bubble_outline_rounded, hint: 'Örn: Soru çözümü, kariyer planlaması...')),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)), side: BorderSide(color: Colors.grey.shade300)), icon: Icon(Icons.calendar_month_rounded, color: primaryColor, size: 18), label: Text(_secilenTarih == null ? "Gün Seç" : _secilenTarih!.toString().substring(0, 10), style: TextStyle(color: darkTextColor, fontSize: 13)), onPressed: () => _tarihSec(context))),
                  const SizedBox(width: 12),
                  Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)), side: BorderSide(color: Colors.grey.shade300)), icon: Icon(Icons.access_time_rounded, color: primaryColor, size: 18), label: Text(_secilenSaat == null ? "Saat Seç" : _secilenSaat!.format(context), style: TextStyle(color: darkTextColor, fontSize: 13)), onPressed: () => _saatSec(context))),
                ],
              ),
              const SizedBox(height: 22),
              _isSaving ? const Center(child: CircularProgressIndicator()) : _buildVistaButton(
                  label: userRol == 'Hoca' ? "Birebir Görüşmeyi Kesinleştir" : "Görüşme Talebini İlet",
                  icon: Icons.calendar_today_rounded,
                  onPressed: () => _randevuAyarla('Görüşme', userRol)
              ),
            ],
          ),
          const SizedBox(height: 26),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: const Text("Aktif Canlı Birebir Seansların", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.3))),
          const SizedBox(height: 12),
          _randevuListesiOlustur('Görüşme'),
        ],
      ),
    );
  }

  Widget _randevuListesiOlustur(String tip) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _toplantilariDinle(tip),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final liste = snapshot.data ?? [];
        if (liste.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24), width: double.infinity,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: Colors.white.withOpacity(0.95), border: Border.all(color: Colors.white24)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tip == 'Toplantı' ? Icons.event_busy_rounded : Icons.speaker_notes_off_rounded, size: 36, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text("Planlanmış herhangi bir $tip kaydı bulunamadı.", style: TextStyle(color: mutedTextColor, fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
              ],
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: liste.length,
          itemBuilder: (context, index) {
            final randevu = liste[index];
            final tarihYazisi = randevu['meeting_date'] != null ? randevu['meeting_date'].toString().replaceAll('T', ' ').substring(0, 16) : 'Belirtilmedi';
            final hocaIsmi = randevu['hoca_ad_soyad'] ?? 'Koç';
            final ogrenciIsmi = randevu['ogrenci_ad_soyad'] ?? 'Öğrenci';
            Color decorationColor = tip == 'Toplantı' ? primaryColor : const Color(0xFF00B0FF);

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white30)),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(backgroundColor: decorationColor.withOpacity(0.08), radius: 22, child: Icon(tip == 'Toplantı' ? Icons.video_camera_front_rounded : Icons.forum_rounded, color: decorationColor, size: 20)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(randevu['title'] ?? '$tip Kaydı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: darkTextColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(tip == 'Toplantı' ? "Grup Toplantısı" : "Birebir Seans", style: TextStyle(fontSize: 11, color: decorationColor, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(height: 1, color: Colors.grey.shade100),
                    const SizedBox(height: 14),
                    Row(children: [const Icon(Icons.person_pin_rounded, size: 15, color: Colors.blueGrey), const SizedBox(width: 8), const Text("Sorumlu Koç: ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey)), Expanded(child: Text(hocaIsmi, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: darkTextColor), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                    const SizedBox(height: 6),
                    Row(children: [const Icon(Icons.school_rounded, size: 15, color: Colors.blueGrey), const SizedBox(width: 8), const Text("Öğrenci: ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey)), Expanded(child: Text(ogrenciIsmi, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: darkTextColor), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                    if (randevu['description'] != null) ...[
                      const SizedBox(height: 12),
                      Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)), child: Text("Gündem Notu: ${randevu['description']}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic))),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.access_alarm_rounded, size: 15, color: decorationColor),
                          const SizedBox(width: 8),
                          Flexible(child: Text("Planlanan Zaman: $tarihYazisi", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: decorationColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _notSekmesi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGlassCard(
            children: [
              _buildSectionHeader(title: "Günlük & Kariyer Notu Deposu", subtitle: "Gelişim süreçlerini, hedeflerini bulut veritabanına kaydet.", icon: Icons.edit_note_rounded),
              const SizedBox(height: 20),
              TextField(controller: _notBaslikController, decoration: _modernInputDecoration(label: 'Not Başlığı', icon: Icons.edit_note_rounded)),
              const SizedBox(height: 14),
              TextField(controller: _notIcerikController, maxLines: 3, decoration: _modernInputDecoration(label: 'Not İçeriği / Detaylar', icon: Icons.notes_rounded)),
              const SizedBox(height: 18),
              _isSaving ? const Center(child: CircularProgressIndicator()) : Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), boxShadow: [BoxShadow(color: Colors.deepOrange.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))]),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)), elevation: 0),
                  icon: const Icon(Icons.save_rounded, color: Colors.white, size: 18), label: const Text("Notu Sisteme Kaydet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), onPressed: _notEkle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: const Text("Kayıtlı Kişisel Notların", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.3))),
          const SizedBox(height: 12),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _notlariDinle(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final notlar = snapshot.data ?? [];
              if (notlar.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24), width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Text("Henüz bir not kaydetmediniz.", textAlign: TextAlign.center, style: TextStyle(color: mutedTextColor, fontSize: 13)),
                );
              }
              return ListView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: notlar.length,
                itemBuilder: (context, index) {
                  final not = notlar[index]; final notId = not['id'] as int;
                  return Dismissible(
                    key: Key(notId.toString()), direction: DismissDirection.endToStart,
                    background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 24)),
                    onDismissed: (direction) => _notSil(notId),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white30)),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.amber.withOpacity(0.08), radius: 22, child: const Icon(Icons.description_rounded, color: Colors.orange, size: 20)),
                        title: Text(not['title'] ?? 'Başlıksız Not', style: TextStyle(fontWeight: FontWeight.bold, color: darkTextColor, fontSize: 14)),
                        subtitle: Text(not['content'] ?? '', style: TextStyle(color: mutedTextColor, fontSize: 12)),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _profilSekmesi(String userRol) {
    final user = _supabase.auth.currentUser;
    final String email = user?.email ?? "E-posta bulunamadı";
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profilVerisiniGetir(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final profilVerisi = snapshot.data;
        final String ad = profilVerisi?['ad'] ?? "İsim Tanımlanmamış";
        final String soyad = profilVerisi?['soyad'] ?? "";
        final String rol = profilVerisi?['rol'] ?? userRol;
        final String basHarf = ad.isNotEmpty && ad != "İsim Tanımlanmamış" ? ad[0].toUpperCase() : "K";

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 550),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: LinearGradient(colors: [primaryColor, const Color(0xFF1E3A8A)], begin: Alignment.topCenter, end: Alignment.bottomCenter), boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))]),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(radius: 54, backgroundColor: Colors.white24, child: CircleAvatar(radius: 50, backgroundColor: Colors.white, child: Text(basHarf, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: primaryColor)))),
                              Positioned(bottom: 0, right: 0, child: GestureDetector(onTap: _fotografSec, child: const CircleAvatar(radius: 18, backgroundColor: Colors.amber, child: Icon(Icons.camera_alt_rounded, size: 16, color: Colors.black87)))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text("$ad $soyad", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Roboto', letterSpacing: 0.5), textAlign: TextAlign.center),
                          const SizedBox(height: 6),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(100)), child: Text(rol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white30)),
                    child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: const Color(0xFFF1F5F9), radius: 22, child: Icon(Icons.alternate_email_rounded, color: primaryColor, size: 18)), title: const Text("Kullanıcı Hesap E-posta", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)), subtitle: Text(email, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: darkTextColor)))
                            ]
                        )
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _hocaOgrenciListesiSekmesi() {
    return ListView(
      padding: const EdgeInsets.all(22.0),
      children: [
        _buildSectionHeader(title: "Aktif Öğrenci Havuzu", subtitle: "Sorumlu olduğunuz koçluk alanındaki güncel öğrenci listesi.", icon: Icons.supervised_user_circle_rounded),
        const SizedBox(height: 20),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _supabase.from('profiles').stream(primaryKey: ['id']).map((maps) => maps.where((element) => element['rol'] == 'Öğrenci').toList()),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final ogrenciler = snapshot.data ?? [];
            if (ogrenciler.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24), width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Text("Sistemde aktif koçluk alan bir öğrenci kaydı bulunamadı.", textAlign: TextAlign.center, style: TextStyle(color: mutedTextColor, fontSize: 13)),
              );
            }
            return ListView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: ogrenciler.length,
              itemBuilder: (context, index) {
                final ogr = ogrenciler[index];
                final ogrenciId = ogr['id'] ?? '';
                final adSoyad = "${ogr['ad'] ?? ''} ${ogr['soyad'] ?? ''}";
                final harf = adSoyad.trim().isNotEmpty ? adSoyad[0].toUpperCase() : "Ö";
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white30)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(radius: 24, backgroundColor: primaryColor.withOpacity(0.08), child: Text(harf, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16))),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(adSoyad, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: darkTextColor), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), const Text("Durum: Portal Katılımcısı", style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold))])),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Divider(height: 1, color: Colors.grey.shade100),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)), padding: const EdgeInsets.symmetric(vertical: 12)), icon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF475569)), label: const Text("Performans İncele", style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.bold)), onPressed: () => _hocaGorevIncelemePenceresiAc(ogrenciId, adSoyad))),
                            const SizedBox(width: 10),
                            Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)), padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0), icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white), label: const Text("Görev Tanımla", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), onPressed: () => _hocaGorevAtamaPenceresiAc(ogrenciId, adSoyad))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCustomDrawer({required String headerTitle, required IconData headerIcon, required List<Widget> children}) {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: Column(
        children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryColor, const Color(0xFF1E3A8A)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(headerIcon, color: Colors.amber, size: 40), const SizedBox(height: 14), Text(headerTitle, style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
          ),
          Expanded(child: Container(color: Colors.white, child: ListView(padding: const EdgeInsets.all(12), children: children))),
        ],
      ),
    );
  }

  Widget _buildCustomDrawerItem({required IconData icon, required String title, required VoidCallback onTap, Color? color}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(leading: Icon(icon, color: color ?? primaryColor, size: 20), title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: color ?? const Color(0xFF334155))), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), onTap: onTap),
    );
  }

  List<BottomNavigationBarItem> _navigasyonItemlariniGetir(String rol) {
    if (rol == 'Hoca') {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.group_rounded), label: "Öğrenciler"),
        BottomNavigationBarItem(icon: Icon(Icons.video_camera_front_rounded), label: "Toplantı"),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: "Görüşme"),
        BottomNavigationBarItem(icon: Icon(Icons.edit_note_rounded), label: "Notlar"),
        BottomNavigationBarItem(icon: Icon(Icons.account_circle_rounded), label: "Profil"),
      ];
    } else {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in_rounded), label: "Görevler"),
        BottomNavigationBarItem(icon: Icon(Icons.video_camera_front_rounded), label: "Toplantı"),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: "Görüşme"),
        BottomNavigationBarItem(icon: Icon(Icons.edit_note_rounded), label: "Notlar"),
        BottomNavigationBarItem(icon: Icon(Icons.account_circle_rounded), label: "Profil"),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profilVerisiniGetir(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: CircularProgressIndicator(color: Colors.white)));
        }
        final profil = snapshot.data;
        final String rol = profil?['rol'] ?? "Öğrenci";

        return Scaffold(
          // --- APPBAR TAŞMA (OVERFLOW) HATASI FITTEDBOX VE FLEXIBLE İLE TAMAMEN ÇÖZÜLDÜ ---
          appBar: AppBar(
            title: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    rol == 'Hoca' ? Icons.diversity_3_rounded : Icons.auto_awesome_rounded,
                    color: const Color(0xFF00B0FF),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rol == 'Hoca' ? "Kariyer Koçluğu Hoca Paneli" : "Kariyer Koçluğu Öğrenci Paneli",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.3,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            centerTitle: true,
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          drawer: _buildCustomDrawer(
            headerTitle: rol == 'Hoca' ? "Workspace Panel" : "Student Dashboard",
            headerIcon: rol == 'Hoca' ? Icons.supervised_user_circle_rounded : Icons.rocket_launch_rounded,
            children: rol == 'Hoca' ? [
              _buildCustomDrawerItem(icon: Icons.group_rounded, title: "Öğrencilerim", onTap: () { Navigator.pop(context); setState(() => _secilenIndeks = 0); }),
              _buildCustomDrawerItem(icon: Icons.video_camera_front_rounded, title: "Toplantıları Yönet", onTap: () { Navigator.pop(context); setState(() => _secilenIndeks = 1); }),
              _buildCustomDrawerItem(icon: Icons.chat_bubble_rounded, title: "Görüşme Talepleri", onTap: () { Navigator.pop(context); setState(() => _secilenIndeks = 2); }),
              _buildCustomDrawerItem(icon: Icons.edit_note_rounded, title: "Notlar", onTap: () { Navigator.pop(context); setState(() => _secilenIndeks = 3); }),
              _buildCustomDrawerItem(icon: Icons.account_circle_rounded, title: "Profilim", onTap: () { Navigator.pop(context); setState(() => _secilenIndeks = 4); }),
              const Divider(),
              _buildCustomDrawerItem(icon: Icons.logout_rounded, title: "Oturumu Kapat", color: Colors.red, onTap: () async { await _supabase.auth.signOut(); if (context.mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const AuthPage())); }),
            ] : [
              _buildCustomDrawerItem(icon: Icons.assignment_turned_in_rounded, title: "Görevler", onTap: () { Navigator.pop(context); setState(() => _secilenIndeks = 0); }),
              _buildCustomDrawerItem(icon: Icons.video_camera_front_rounded, title: "Toplantılarım", onTap: () { Navigator.pop(context); setState(() => _secilenIndeks = 1); }),
              _buildCustomDrawerItem(icon: Icons.chat_bubble_rounded, title: "Görüşmelerim", onTap: () { Navigator.pop(context); setState(() => _secilenIndeks = 2); }),
              _buildCustomDrawerItem(icon: Icons.edit_note_rounded, title: "Notlarım", onTap: () { Navigator.pop(context); setState(() => _secilenIndeks = 3); }),
              _buildCustomDrawerItem(icon: Icons.account_circle_rounded, title: "Profilim", onTap: () { Navigator.pop(context); setState(() => _secilenIndeks = 4); }),
              const Divider(),
              _buildCustomDrawerItem(icon: Icons.logout_rounded, title: "Oturumu Kapat", color: Colors.red, onTap: () async { await _supabase.auth.signOut(); if (context.mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const AuthPage())); }),
            ],
          ),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F172A), // Gece Mavisi
                  Color(0xFF1E1B4B), // Koyu İndigo
                  Color(0xFF312E81), // Canlı Gece Mavisi
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: IndexedStack(
                key: ValueKey<int>(_secilenIndeks),
                index: _secilenIndeks,
                children: [
                  rol == 'Hoca' ? _hocaOgrenciListesiSekmesi() : _gorevSekmesi(),
                  _toplantiSekmesi(rol),
                  _gorusmeSekmesi(rol),
                  _notSekmesi(),
                  _profilSekmesi(rol),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -4))]),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed, currentIndex: _secilenIndeks, backgroundColor: Colors.white,
              selectedItemColor: primaryColor, unselectedItemColor: Colors.grey.shade400,
              selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11), unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
              onTap: (index) => setState(() => _secilenIndeks = index),
              items: _navigasyonItemlariniGetir(rol),
            ),
          ),
        );
      },
    );
  }
}