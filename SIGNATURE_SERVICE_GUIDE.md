# 📝 Руководство по реализации сервиса подписей в PDF Scanner

## 🏗️ Архитектура системы подписей

### Обзор компонентов

Система подписей состоит из нескольких ключевых компонентов, работающих вместе для обеспечения точного позиционирования и сохранения подписей в PDF документах.

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   SignatureService  │    │     EditService     │    │   PDFEditorView     │
│                     │    │                     │    │                     │
│ • Создание подписей │────│ • Управление        │────│ • Отображение PDF   │
│ • Сохранение        │    │   активными         │    │ • Координатная      │
│ • Загрузка          │    │   подписями         │    │   система           │
└─────────────────────┘    │ • Конвертация       │    └─────────────────────┘
                          │   координат         │    
                          └─────────────────────┘    
                                     │                
                          ┌─────────────────────┐    
                          │  SignatureOverlay   │    
                          │                     │    
                          │ • Drag & Drop       │    
                          │ • Координатная      │    
                          │   конвертация       │    
                          │ • Финализация       │    
                          └─────────────────────┘    
```

## 📋 Основные компоненты

### 1. SignatureService
**Файл:** `Sources/Service/PDFServices/Editor/SignatureService.swift`

Отвечает за создание, сохранение и загрузку подписей.

```swift
@MainActor
final class SignatureService: ObservableObject {
    @Published var savedSignatures: [SavedSignature] = []
    @Published var currentDrawing = PKDrawing()
    
    // Создание подписи из PKDrawing
    func createSignatureFromDrawing() -> UIImage?
    
    // Сохранение подписи для переиспользования
    func saveSignature(_ image: UIImage, name: String)
    
    // Загрузка сохраненных подписей
    func loadSavedSignatures()
}
```

### 2. EditService 
**Файл:** `Sources/Service/PDFServices/Editor/EditService.swift`

Главный сервис для редактирования PDF, управляет активными подписями и координатной системой.

```swift
@MainActor
final class EditService: ObservableObject {
    // PDF View reference для точных координат
    weak var pdfViewRef: PDFView?
    
    // Активная подпись в режиме наложения
    @Published var activeSignatureOverlay: IdentifiablePDFAnnotation?
    
    // Получение реальных размеров PDF display
    func getActualPDFDisplaySize() -> (size: CGSize, offset: CGPoint)?
    
    // Создание overlay для подписи
    func createSignatureOverlay(with signature: UIImage)
    
    // Финализация подписи в PDF
    func finalizeSignatureOverlay()
}
```

### 3. SignatureOverlay
**Файл:** `Sources/Presentation/Main/Editor/Components/SignatureOverlay.swift`

SwiftUI компонент для отображения и манипулирования подписью перед финализацией.

```swift
struct SignatureOverlay: View {
    @ObservedObject var editService: EditService
    @Binding var annotation: IdentifiablePDFAnnotation
    let geometry: GeometryProxy
    
    // Drag gesture для перемещения
    var dragGesture: some Gesture
    
    // Сохранение позиции при завершении drag
    private func saveSignaturePosition()
}
```

### 4. ImageAnnotation
**Файл:** `Sources/Service/PDFServices/Editor/AnnotationsService.swift`

Кастомная PDF аннотация для отображения изображений подписей в PDF.

```swift
class ImageAnnotation: PDFAnnotation {
    private let _image: UIImage
    
    init(bounds: CGRect, image: UIImage)
    
    override func draw(with box: PDFDisplayBox, in context: CGContext)
}
```

## 🎯 Ключевые принципы координатной системы

### Проблема координатных систем

PDF и SwiftUI используют разные системы координат:

- **SwiftUI**: (0,0) в левом верхнем углу, Y увеличивается вниз
- **PDF**: (0,0) в левом нижнем углу, Y увеличивается вверх

### Решение: Точная конвертация координат

#### 1. Получение реальных размеров PDF
```swift
func getActualPDFDisplaySize() -> (size: CGSize, offset: CGPoint)? {
    guard let pdfView = pdfViewRef,
          let page = pdfDocument?.page(at: currentPageIndex) else { return nil }
    
    let pageRect = page.bounds(for: .mediaBox)
    let displayRect = pdfView.convert(pageRect, from: page)
    
    return (size: displayRect.size, offset: CGPoint(x: displayRect.origin.x, y: displayRect.origin.y))
}
```

#### 2. Конвертация координат с учетом offset
```swift
private func saveSignaturePosition() {
    // Получаем реальные размеры и отступы PDF
    let (displaySize, displayOffset) = editService.getActualPDFDisplaySize()
    
    // Убираем отступы перед масштабированием
    let adjustedViewX = annotation.midPosition.x - displayOffset.x
    let adjustedViewY = annotation.midPosition.y - displayOffset.y
    
    // Конвертируем в PDF координаты
    let scaleX = pageRect.width / displaySize.width
    let scaleY = pageRect.height / displaySize.height
    
    let pdfCenterX = adjustedViewX * scaleX
    let pdfCenterY = pageRect.height - (adjustedViewY * scaleY) // Y-flip
}
```

### 3. Использование .pdfDocumentFrame() модификатора
```swift
GeometryReader { geometry in
    // PDF + overlays
}
.pdfDocumentFrame(
    pageRect: editService.currentPage?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 595, height: 842),
    rotation: Int(editService.currentPage?.rotation ?? 0),
    maxRatio: 0.7
)
```

Модификатор обеспечивает:
- Правильный aspect ratio
- Учет поворота страницы  
- Фиксированные размеры для точной конвертации

## 🔧 Пошаговая реализация

### Шаг 1: Создание SignatureService

```swift
@MainActor
final class SignatureService: ObservableObject {
    @Published var savedSignatures: [SavedSignature] = []
    @Published var currentDrawing = PKDrawing()
    @Published var isCreatingSignature = false
    
    private let storage = SignatureStorage()
    
    init() {
        loadSavedSignatures()
    }
    
    func createSignatureFromDrawing() -> UIImage? {
        guard !currentDrawing.strokes.isEmpty else { return nil }
        
        // Создание изображения из PKDrawing
        let renderer = PKCanvasView()
        renderer.drawing = currentDrawing
        renderer.backgroundColor = UIColor.clear
        
        return renderer.asUIImage()
    }
    
    func saveSignature(_ image: UIImage, name: String) {
        let signature = SavedSignature(id: UUID(), name: name, image: image, createdAt: Date())
        savedSignatures.append(signature)
        storage.save(signatures: savedSignatures)
    }
    
    func loadSavedSignatures() {
        savedSignatures = storage.load()
    }
}
```

### Шаг 2: Интеграция с EditService

```swift
// В EditService добавить:
@Published var signatureService = SignatureService()

func createSignatureOverlay(with signature: UIImage) {
    guard let page = currentPage else { return }
    
    let pageRect = page.bounds(for: .mediaBox)
    let centerX = pageRect.width / 2
    let centerY = pageRect.height / 2
    
    // Создание annotation
    let bounds = CGRect(x: centerX - 100, y: centerY - 50, width: 200, height: 100)
    let imageAnnotation = ImageAnnotation(bounds: bounds, image: signature)
    
    // Создание identifiable annotation для overlay
    let identifiableAnnotation = IdentifiablePDFAnnotation(
        annotation: imageAnnotation,
        position: CGPoint(x: centerX, y: centerY),
        midPosition: CGPoint(x: 0.5, y: 0.5),
        boundingBox: bounds,
        scale: 1.0
    )
    
    activeSignatureOverlay = identifiableAnnotation
    hasUnsavedChanges = true
}
```

### Шаг 3: Создание SignatureOverlay

```swift
struct SignatureOverlay: View {
    @ObservedObject var editService: EditService
    @Binding var annotation: IdentifiablePDFAnnotation
    let geometry: GeometryProxy
    
    var body: some View {
        if let image = getAnnotationImage() {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(
                    width: image.size.width * annotation.scale,
                    height: image.size.height * annotation.scale
                )
                .position(annotation.midPosition)
                .gesture(dragGesture)
                .gesture(magnificationGesture)
        }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let newPosition = clampedPosition(
                    for: getAnnotationImage()?.size ?? .zero,
                    viewPosition: value.location
                )
                annotation.midPosition = newPosition
                saveSignaturePosition()
            }
    }
    
    private func saveSignaturePosition() {
        // Конвертация координат как описано выше
        // ...
    }
}
```

### Шаг 4: PDFEditorView интеграция

```swift
struct PDFEditorView: UIViewRepresentable {
    @ObservedObject var editService: EditService
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        
        // Конфигурация PDFView
        pdfView.backgroundColor = UIColor.systemBackground
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        
        // ВАЖНО: Установка ссылки для координат
        editService.setPDFViewReference(pdfView)
        
        return pdfView
    }
}
```

## ⚠️ Важные моменты

### 1. Координатная синхронизация
- Всегда используйте `getActualPDFDisplaySize()` для точных размеров
- Учитывайте offset PDF display area
- Применяйте `.pdfDocumentFrame()` модификатор для стабильной геометрии

### 2. Память и производительность  
- Используйте `weak` ссылки на PDFView
- Очищайте активные overlay после финализации
- Сохраняйте изображения подписей в оптимизированном формате

### 3. UI/UX
- **Видимая кнопка "Save Signature"**: отдельная кнопка для сохранения (не в меню)
- **Два режима сохранения**: 
  - "Save Signature" - только сохранить для будущего использования
  - "Save & Use" - сохранить и сразу использовать (через меню)
- **Visual feedback**: подтверждение сохранения и автопереход на вкладку "Saved"
- **Drag & Drop feedback**: визуальная обратная связь при перемещении
- **Clamping**: предотвращение выхода подписи за границы PDF
- **Clear instructions**: подсказки пользователю на каждом этапе

### 4. Отладка
- Используйте подробные логи для tracking координат
- Логируйте все этапы конвертации координат
- Тестируйте на разных размерах PDF и поворотах

## 🔄 Workflow использования

### 1. Создание новой подписи
1. **Открыть SignatureCreatorView**: через кнопку "Signature" в EditService
2. **Рисование**: на вкладке "Draw" нарисовать подпись пальцем
3. **Выбор цвета**: выбрать цвет из доступных вариантов
4. **Сохранение опционально**: нажать "Save Signature" для сохранения
   - Ввести имя подписи
   - Подпись сохраняется в файловую систему и появляется во вкладке "Saved"
5. **Использование**: нажать "Use Signature" для добавления в PDF

### 2. Использование сохраненной подписи
1. **Переход на вкладку "Saved"**: просмотр ранее сохраненных подписей
2. **Выбор подписи**: нажать "Use" на нужной подписи
3. **Позиционирование**: перетащить и масштабировать overlay
4. **Финализация**: нажать "Done" для добавления в PDF

### 3. Управление сохраненными подписями
- **Просмотр**: все подписи отображаются в grid layout
- **Удаление**: кнопка корзины с подтверждением
- **Информация**: имя подписи и дата создания

## 💾 Система сохранения подписей

### Модель данных
```swift
struct SavedSignature: Identifiable, Codable {
    var id = UUID()
    let name: String        // Имя подписи
    let imageName: String   // Имя файла в Documents
    let createdDate: Date   // Дата создания
    let color: String       // Цвет в hex формате
}
```

### Хранение
- **Файловая система**: PNG изображения в Documents directory
- **Метаданные**: UserDefaults для быстрого доступа
- **Автоочистка**: удаление файла при удалении записи

### UI Components
1. **SignatureCreatorView**: Главный экран с двумя вкладками
   - "Draw": рисование новой подписи с цветами
   - "Saved": просмотр и выбор сохраненных подписей

2. **SavedSignatureCell**: Карточка сохраненной подписи
   - Превью изображения
   - Информация (имя, дата)
   - Кнопки "Use" и удаление

3. **SignatureDrawingView**: Canvas для рисования
   - Gesture handling для drag drawing
   - Визуальная обратная связь
   - Placeholder когда пусто

## 📚 Дополнительные ресурсы

- [Apple PDFKit Documentation](https://developer.apple.com/documentation/pdfkit)
- [SwiftUI Gestures Guide](https://developer.apple.com/documentation/swiftui/gestures)
- [Coordinate Space Transformations](https://developer.apple.com/documentation/swiftui/coordinatespace)

---

---

## 🆕 Новые функции (декабрь 2024)

### Улучшенный UI для сохранения подписей

#### Добавлена кнопка "Save Signature"
```swift
// В drawingActionButtons
VStack(spacing: 12) {
    // Use Signature button
    Button("Use Signature") {
        useCurrentSignature()
    }
    .font(.medium(16))
    .foregroundColor(.white)
    .frame(maxWidth: .infinity, height: 48)
    .background(signatureService.hasSignature ? Color.appPrimary : Color.gray)
    .cornerRadius(12)
    .disabled(!signatureService.hasSignature)
    
    // Save Signature button - НОВАЯ
    Button("Save Signature") {
        saveAndUseMode = false
        showingNameAlert = true
    }
    .font(.medium(16))
    .foregroundColor(signatureService.hasSignature ? Color.appPrimary : Color.gray)
    .frame(maxWidth: .infinity, height: 48)
    .background(Color.clear)
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appPrimary, lineWidth: 1))
    .disabled(!signatureService.hasSignature)
}
```

#### Два режима сохранения
```swift
@State private var saveAndUseMode = false  // true for "Save & Use", false for "Save only"

// Метод только для сохранения
private func saveSignatureOnly() {
    guard !signatureName.trim().isEmpty,
          let signatureImage = signatureService.generateSignatureImage() else { return }
    
    let colorHex = signatureService.selectedColor.toHex()
    
    if signatureStorage.saveSignature(signatureImage, name: signatureName.trim(), color: colorHex) != nil {
        signatureName = ""
        showingSavedAlert = true  // Показываем подтверждение
        
        // Автопереход на вкладку Saved
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            selectedTab = 1
        }
    }
}
```

#### Улучшенные alerts
```swift
.alert("Save Signature", isPresented: $showingNameAlert) {
    TextField("Signature name", text: $signatureName)
    Button("Cancel", role: .cancel) {
        signatureName = ""
        saveAndUseMode = false
    }
    Button(saveAndUseMode ? "Save & Use" : "Save") {
        if saveAndUseMode {
            saveAndUseSignature()  // Сохранить и использовать
        } else {
            saveSignatureOnly()    // Только сохранить
        }
        saveAndUseMode = false
    }
    .disabled(signatureName.trim().isEmpty)
} message: {
    Text(saveAndUseMode ? 
         "Enter a name for this signature and use it immediately" : 
         "Enter a name to save this signature for later use")
}
.alert("Signature Saved", isPresented: $showingSavedAlert) {
    Button("OK") { }
} message: {
    Text("Your signature has been saved successfully and can be found in the Saved tab.")
}
```

### Преимущества нового подхода

1. **Больше гибкости**: пользователь может сохранить подпись без использования
2. **Лучшая видимость**: кнопка "Save Signature" всегда видна
3. **Улучшенный UX**: автопереход на вкладку "Saved" после сохранения
4. **Clear feedback**: подтверждение успешного сохранения

---

## 📄 Новая функция: Добавление страниц (декабрь 2024)

### Компактный индикатор страниц

#### PageIndicator компонент
```swift
// Отображается над тулбаром
HStack {
    Text("Page").font(.regular(12)).foregroundColor(.appSecondary)
    Text("\(currentPageIndex + 1) / \(pageCount)").font(.medium(14))
    
    // Кнопка "Add Page" появляется только на последней странице
    if editService.currentPageIndex == document.pageCount - 1 {
        Button("+ Add Page") { 
            editService.showAddPageOptions() 
        }
    }
}
.background(Color.appSurface.opacity(0.9))
.cornerRadius(20)
```

#### Интеграция в EditorView
```swift
// Располагается между PDF и тулбаром
if editService.isToolbarVisible {
    HStack {
        Spacer()
        PageIndicator(editService: editService)  // Компактно по центру
        Spacer()
    }
    .padding(.bottom, 8)
}
```

### Добавление новых страниц

#### AddPageActionSheet компонент
```swift
VStack {
    Text("Add New Page").font(.semiBold(20))
    
    // Три опции добавления:
    Button("Scan with Camera") { editService.addPageFromCamera() }
    Button("Import from Files") { editService.addPageFromFiles() }  
    Button("Choose from Photos") { editService.addPageFromPhotos() }
}
.presentationDetents([.fraction(0.6)])  // Половина экрана
```

#### EditService методы
```swift
// Показать опции добавления страницы
func showAddPageOptions() {
    showingAddPageActionSheet = true
}

// Добавить страницу из изображения
func addPageToDocument(from image: UIImage) {
    let newPage = PDFPage(image: image)
    document.insert(newPage, at: document.pageCount)
    
    // Автопереход на новую страницу
    currentPageIndex = document.pageCount - 1
    annotationsService.updateCurrentPage(currentPageIndex)
    
    hasUnsavedChanges = true
}
```

#### Три способа добавления страниц

1. **Camera Scan** 📸
```swift
.sheet(isPresented: $editService.showingCameraScan) {
    // TODO: Интеграция с камерой для сканирования
    CameraScanView()
}
```

2. **File Import** 📁  
```swift
.fileImporter(
    isPresented: $editService.showingFileImporter,
    allowedContentTypes: [.image, .pdf]
) { result in
    if let url = result.success?.first,
       let data = try? Data(contentsOf: url) {
        editService.addPageToDocument(from: data)
    }
}
```

3. **Photos Library** 🖼️
```swift
.photosPicker(
    isPresented: $editService.showingPhotosPicker,
    selection: $selectedPhotosPickerItems,
    matching: .images
)
.onChange(of: selectedPhotosPickerItems) { 
    // Добавляет выбранное изображение как новую страницу
    editService.addPageToDocument(from: image)
}
```

### Обновленный UI/UX

#### Упрощенный тулбар
```swift
// Убрали отображение страниц из тулбара - теперь только стрелки
HStack(spacing: 16) {
    Button { editService.goToPreviousPage() } {
        Image(systemName: "chevron.left").font(.medium(18))
    }
    
    Button { editService.goToNextPage() } {  
        Image(systemName: "chevron.right").font(.medium(18))
    }
}
```

#### Улучшенная навигация
- ✅ **Компактный индикатор** страниц над тулбаром
- ✅ **Кнопка добавления** появляется только на последней странице  
- ✅ **Три способа** добавления: камера, файлы, фото
- ✅ **Автонавигация** на новую страницу после добавления
- ✅ **Упрощенный тулбар** только с навигационными стрелками

### Workflow использования

1. **Навигация по страницам** → используй стрелки в тулбаре ⬅️➡️
2. **На последней странице** → появляется кнопка "+ Add Page" 
3. **Выбери способ добавления** → камера/файлы/фото 📸📁🖼️
4. **Автопереход** → на только что добавленную страницу ✅
5. **Продолжай редактирование** → на новой странице 🎯

**Примечание**: Теперь индикатор страниц отображается компактно над тулбаром, а функция добавления страниц доступна интуитивно когда действительно нужна (на последней странице).