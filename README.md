# Technical Test - Shift Engineer (DevOps)
PT Simple Journey Indonesia

Dokumentasi implementasi CI/CD, Containerization, dan Hotfix Deployment tanpa rebuild container penuh untuk aplikasi Go HTTP Server.

---

## Ringkasan Project & Repository

- **Application Name**: `technical-test-simple-server`
- **Docker Hub Repository**: [mirzarama27/technical-test-simple-server](https://hub.docker.com/repository/docker/mirzarama27/technical-test-simple-server)
- **Jenkins Server**: `https://jenkins.mmrh.me/`
- **Jenkins Credential Access**:
  - Username: `user2`
  - Password: `password123!`
- **Target Deployment Server**: `208.87.132.201` (`mirza@208.87.132.201`)
- **Port Exposed**: `8080` (HTTP)

---

## Bagian I: Build (Docker Multi-stage)

### 1. Implementasi Dockerfile
Multi-stage build memisahkan lingkungan kompilasi dengan runtime minimal:

- **Stage Builder (`golang:1.26-alpine`)**:
  - Kompilasi binary Go statis tanpa dependency C (`CGO_ENABLED=0 GOOS=linux GOARCH=amd64`).
  - Injeksi versi saat kompilasi via flag `-ldflags="-X main.version=${APP_VERSION}"`.
  - Mengkompilasi dua binary:
    1. `/app/server` (`./cmd/app`): HTTP server utama.
    2. `/tool/manager` (`./cmd/manager`): Process supervisor untuk menangani live-reload via signal `SIGUSR1`.
- **Stage Final (`alpine:3.22`)**:
  - Hanya menyalin binary `/app/server` dan `/tool/manager`.
  - Menggunakan Alpine sebagai runtime base image.

### 2. Alasan Pemilihan Base Image
- **Pilihan**: `alpine:3.22`
- **Alasan**:
  - Ukuran sangat ringan (~7-8 MB base image).
  - Tetap menyediakan utility dasar shell (`sh`, `ln`, `mv`) yang esensial untuk orchestrasi pergantian binary secara atomik di dalam container tanpa membutuhkan Go toolchain pada host maupun runtime container.

### 3. Perintah Build
```bash
docker build --build-arg APP_VERSION=1.0.1 -t mirzarama27/technical-test-simple-server:1.0.1 .
```

### 4. Ukuran Image & Penjelasan
- **Ukuran Image**: `~19.6 MB`
```bash
$ docker images | grep technical-test-simple-server
mirzarama27/technical-test-simple-server:1.0.1    62fb83d81c3c    19.6MB
```
- **Penjelasan**: Base Alpine (~7-8 MB) ditambah dua binary Go yang di-link secara statis (`server` ~6 MB dan `manager` ~5 MB). Tanpa menyertakan Go SDK/toolchain compiler (yang berukuran ~800 MB+ pada builder stage).

---

## Bagian II: Deploy & Mekanisme Hotfix (Zero Downtime / Tanpa Rebuild)

Sesuai requirement Point 5: mengganti binary tanpa full docker build dari awal dan tanpa mematikan/menghapus container yang sedang berjalan.

### 1. Arsitektur Process Supervisor (`manager`)
Container menjalankan entrypoint `/tool/manager` (`cmd/manager/main.go`):
- `manager` menjalankan child process `/app/server`.
- `manager` mendengarkan signal sistem:
  - `SIGUSR1`: Menghentikan child `/app/server` secara graceful (SIGTERM) dan me-restart process `/app/server` baru tanpa mematikan container.
  - `SIGTERM`: Menghentikan seluruh proses dan container secara rapi.

### 2. Skema Volume & Pergantian Binary Atomik
Container dijalankan dengan me-mount host directory `./releases` ke `/releases`:
```bash
docker run -d \
  -v "./releases:/releases" \
  -p 8080:8080 \
  --restart unless-stopped \
  --name technical-test-simple-server \
  mirzarama27/technical-test-simple-server:1.0.1
```

Langkah update binary (`scripts/update.sh`):
1. Binary versi baru diekstrak ke host pada `./releases/<VERSION>/server`.
2. Binary di-link secara atomik di dalam container:
   ```bash
   docker exec technical-test-simple-server sh -ec "
       ln -s '/releases/<VERSION>/server' /app/server.next
       mv -Tf /app/server.next /app/server
   "
   ```
3. Kirim signal reload ke supervisor tanpa mematikan container:
   ```bash
   docker kill --signal=USR1 technical-test-simple-server
   ```
4. Status versi aktif disimpan ke `./state/current.txt` dan versi sebelumnya di `./state/previous.txt`.

### 3. Ekstraksi Binary Rilis
Binary versi baru diambil dari image tanpa re-run aplikasi via:
```bash
docker run -d --name release-container mirzarama27/technical-test-simple-server:<VERSION>
docker cp release-container:/app/server ./releases/<VERSION>/server
docker rm -f release-container
```

### 4. Bukti Hasil Verifikasi (Curl Output)

- **Sebelum update**:
```bash
$ curl -s http://208.87.132.201:8080/
Hello, DevOps! version=1.0.0
```

- **Setelah update (swap + restart signal)**:
```bash
$ curl -s http://208.87.132.201:8080/
Hello, DevOps! version=1.0.1
```

- **Waktu Downtime**: < 1 detik (hanya restart child process oleh `manager`, socket container tidak teardown).

### 5. Justifikasi Pendekatan Hotfix
- **[PLACEHOLDER: Penjelasan 3-5 kalimat mengapa pendekatan manager + volume symlink dipilih untuk skenario production hotfix]**
  - *Contoh catatan*: Pendekatan ini memisahkan siklus hidup container runtime dari file binary. Dengan memanfaatkan supervisor process berbasis signal OS (`SIGUSR1`) dan pergantian file atomik via symlink (`mv -Tf`), rilis perbaikan bug darurat dapat diterapkan dalam hitungan milidetik tanpa memicu alokasi IP/port ulang, tanpa memutus container network stack, dan tanpa overhead build ulang Docker layer di environment produksi.

---

## Bagian III: CI/CD Pipeline (Jenkinsfile)

Alur pipeline didefinisikan dalam declarative `Jenkinsfile`.

### 1. Jenkins Credentials Binding
Pipeline tidak menggunakan plaintext secret / password:
- `docker-hub-pat`: Tipe *Username with Password* untuk autentikasi registry Docker Hub (`docker login`).
- `deploy-ssh`: Tipe *SSH Username with private key* untuk koneksi remote deployment via plugin `sshagent`.

### 2. Alur Tahapan Stage Pipeline

1. **Stage: Checkout**
   - Mengambil commit source code terbaru dari git branch `main`.
   ```groovy
   checkout scm
   ```

2. **Stage: Check Version**
   - Mengekstrak variabel `VERSION` dari `Makefile`.
   ```bash
   make -s --eval='print-version:; @echo $(VERSION)' print-version
   ```

3. **Stage: Build And Push**
   - Menjalankan build Docker image lokal:
     ```bash
     make build
     ```
   - Login ke Docker Hub secara aman menggunakan PAT:
     ```bash
     echo "$DOCKERPAT" | docker login --username "$DOCKERUSERNAME" --password-stdin
     ```
   - Push image ke registry:
     ```bash
     make push
     ```

4. **Stage: Deploy And Integration Test**
   - Menjalankan remote SSH ke server `208.87.132.201`:
     - Sinkronisasi repository ke commit terbaru:
       ```bash
       git fetch origin main && git checkout main && git reset --hard origin/main
       ```
     - Ekstraksi binary rilis baru ke host:
       ```bash
       make release
       ```
     - Swap binary dan reload supervisor:
       ```bash
       make update
       ```
     - Uji integrasi / health-check:
       ```bash
       make health || { echo 'Health check failed'; make rollback; exit 1; }
       ```

5. **Stage: Post Actions**
   - Menampilkan status keberhasilan atau kegagalan pipeline ke console log.

---

## Bagian IV: Pertanyaan & Evaluasi Teknis

### 1. Bagaimana pipeline menangani Rollback jika Deploy gagal di tengah jalan?
- **Mekanisme Otomatis**:
  - Pada stage deployment, perintah `make health` dijalankan setelah `make update`.
  - Jika HTTP response gagal (non-200 / timeout), block shell conditional mengeksekusi `make rollback` sebelum keluar dengan `exit 1`.
  - Skrip `rollback.sh` membaca versi terakhir dari `./state/previous.txt`, mengembalikan symlink binary `/app/server` ke rilis sebelumnya, me-reload process dengan `docker kill --signal=USR1`, lalu mengembalikan state version.
- **[PLACEHOLDER: Tambahan catatan arsitektur rollback jika container crash total]**

### 2. Bukti Screenshot / Log Eksekusi Sukses
- **[PLACEHOLDER: Lampirkan screenshot antarmuka Jenkins stage view berwarna hijau]**
- **[PLACEHOLDER: Lampirkan potongan log konsol Jenkins yang menunjukkan build & deploy sukses]**

---

## Panduan Perintah Operasional (Cheatsheet)

| Perintah | Fungsi |
|---|---|
| `make build` | Build image Docker dengan versi dinamis |
| `make push` | Push image ke Docker Hub |
| `make run` | Menjalankan container pertama kali dengan volume mount |
| `make release` | Ekstrak binary versi baru ke `./releases/<VERSION>/server` |
| `make update` | Mengganti symlink binary di dalam container & kirim signal `SIGUSR1` |
| `make health` | Memverifikasi endpoint HTTP server (`curl http://208.87.132.201:8080/`) |
| `make rollback` | Mengembalikan binary container ke versi di `./state/previous.txt` |
| `make logs` | Melihat log output aplikasi |
| `make down` | Menghentikan dan menghapus container |
