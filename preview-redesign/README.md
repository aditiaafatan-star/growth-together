# Preview Redesign — Growth Together

File di folder ini adalah PROTOTYPE terpisah untuk review UI/UX & arsitektur. Bukan bagian dari aplikasi/APK asli dan tidak tersambung ke kode, Gradle, Android, atau Supabase project asli. Buka langsung di browser (double-click / drag ke Chrome atau Edge) untuk melihat previewnya.

## Isi
- `dashboard-redesign-preview.html` — mockup redesign dashboard (progress card + timeline). **Status: ditolak, tidak dipakai.**
- `hero-cursor-effect-preview.html` — efek cursor interaktif untuk hero index.html. **Status: SUDAH DITERAPKAN ke index.html.**
- `app-gamified-dashboard-preview.html` — Fase 2: preview dashboard app.html versi gamifikasi penuh (Today's Missions, Level/XP, Streak, My Plants, Team Leaderboard, Journal) + preview onboarding 3 langkah. **Status: menunggu review.**
- `index-dashboard-upgrade-preview.html` — Fase 2: preview upgrade dashboard/journal di index.html — TANPA missions/XP/level/streak (cuma leaderboard), fokus ke hierarchy & kejelasan. **Status: menunggu review.**
- Redesign section #plants dengan foto & tab (Bougainvillea & Portulaca). **Status: SUDAH DITERAPKAN ke index.html.**

## Status
- Efek hero cursor interactive dan Redesign section #plants SUDAH DITERAPKAN ke `index.html`.
- Prototype Fase 2 (gamifikasi app.html dan upgrade journal index.html) masih berupa preview dan menunggu review.

## Aman dihapus
Folder `preview-redesign/` ini berdiri sendiri. Kalau ada preview yang tidak dipakai, filenya bisa dihapus kapan saja tanpa memengaruhi project asli.

## Kalau ada redesign yang disetujui
Perubahan akan diterapkan langsung ke file project asli terkait (styling & markup saja — logic yang sudah ada tetap dipakai), bukan dengan menimpa file dari folder ini. Untuk perubahan yang butuh Supabase (XP/level/streak/leaderboard), migrasi SQL akan didiskusikan & disetujui dulu sebelum dijalankan ke database production.
