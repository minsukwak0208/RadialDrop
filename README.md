# RadialDrop (Tangerine for Mac 클론)

macOS 제스처 기반 100% 로컬 파일 변환 및 조작 유틸리티입니다.  
별도의 창을 열 필요 없이 Finder에서 파일을 드래그하면서 `Shift` 키를 누르면 마우스 커서 위치에 원형 휠(Radial Menu)이 나타나고, 원하는 포맷에 드롭하여 즉시 변환합니다.

---

## 🌟 주요 기능

### 1. 이미지 (Image)
- **상호 변환**: PNG, JPEG, WebP, HEIC, TIFF, PDF
- **고급 도구 (`Shift + Option`)**:
  - Compress 50% (이미지 용량 최적화)
  - Strip EXIF (개인정보 및 메타데이터 제거)
  - Grayscale (흑백 변환)

### 2. 문서 및 PDF (Document & PDF)
- **PDF Split**: 다중 페이지 PDF를 개별 페이지 PDF로 분할
- **PDF Compress**: 페이지 최적화 재인코딩으로 PDF 용량 경량화
- **PDF to Images**: 각 페이지를 고해상도(Retina 2x) PNG 또는 JPG 이미지로 일괄 추출
- **HWP / HWPX 변환**: 한컴오피스 한글 연동을 통해 HWP를 **PDF** 및 **Word(DOCX)**로 완벽 변환

### 3. 동영상 및 오디오 (Media)
- **동영상 변환**: MP4, MOV, 고화질 GIF 생성
- **오디오 추출/변환**: MP3, WAV, M4A

---

## 🚀 설치 및 사용 방법

### 1. 설치
1. GitHub 저장소의 [Releases](../../releases) 페이지에서 최신 `RadialDrop.zip`을 다운로드합니다.
2. 압축을 풀고 `RadialDrop.app`을 `/Applications` (응용 프로그램) 폴더로 이동합니다.
3. 앱을 실행합니다. (메뉴바에 원형 아이콘이 나타납니다.)

### 2. 필수 권한 설정
- 글로벌 마우스 드래그 및 `Shift` 키 조합을 감지하기 위해 **손쉬운 사용(Accessibility)** 권한이 필요합니다.
- 상단 메뉴바의 RadialDrop 아이콘을 클릭한 뒤 **"Request Accessibility Permission..."**을 누르고, 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서 `RadialDrop`을 허용해 주세요.

### 3. 사용법
1. Finder에서 파일(이미지, PDF, HWP, 영상 등)을 클릭하고 드래그를 시작합니다.
2. 드래그 중인 상태에서 **`Shift`** 키를 누릅니다.
3. 마우스 커서 위치에 원형 휠이 나타납니다.
4. 원하는 포맷 슬라이스 위로 마우스를 이동한 뒤 마우스 버튼을 놓아 드롭합니다.
5. 원본 파일이 있는 폴더에 변환된 결과물이 즉시 생성됩니다.

---

## 🛠 소스코드 직접 빌드

```bash
git clone https://github.com/minsukwak0208/RadialDrop.git
cd RadialDrop

# 릴리즈 앱 번들 생성
./build_app.sh

# 앱 실행
open dist/RadialDrop.app
```

---

## 🔒 프라이버시 및 보안
모든 변환 및 가공 작업은 외부 서버 전송 없이 100% 사용자의 Mac 로컬에서만 수행됩니다.
