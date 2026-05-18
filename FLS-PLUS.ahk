; FLS-PLUS (Files Plus) v1.0
; Поддержка кодировок: UTF-8, CP1251
; Формат снимка: === путь | кодировка ===
#Requires AutoHotkey v2.0
#SingleInstance Force

; === КОНСТАНТЫ ===
APP_NAME := "FLS-PLUS"
APP_VERSION := "1.0"
iniFile := A_ScriptDir "\FLS-PLUS.ini"
logFile := A_ScriptDir "\FLS-PLUS.log"
MAX_HISTORY := 20
MAX_BOOKMARKS := 15

; === ИКОНКИ (Unicode символы) ===
ICO_FOLDER    := "📁"
ICO_FILE      := "📄"
ICO_SAVE      := "💾"
ICO_OPEN      := "📂"
ICO_COPY      := "📋"
ICO_CLEAR     := "🗑️"
ICO_EXPLORE   := "🔍"
ICO_PACK      := "📦"
ICO_UNPACK    := "📂"
ICO_BROWSE    := "..."
ICO_BOOKMARK  := "⭐"
ICO_ADD_BM    := "➕⭐"
ICO_DEL_BM    := "➖⭐"

; === ПЕРЕМЕННЫЕ ===
currentTreeRaw := ""
currentTree := ""
lastFolder := ""
lastSaveFolder := ""
alwaysOnTop := 0
savedTabIndex := 1
helpWindow := ""
tabNames := ["Дерево", "Свернуть", "Развернуть", "Справка"]    ; <-- ДОБАВЛЕНО: названия вкладок для заголовка окна

; Глобальные контролы для доступа из функций
treeEdit := ""
helpEdit := ""
ddFolderHistory := ""
ddFileHistory := ""
ddSnapshotHistory := ""
ddTargetFolder := ""
progressPack := ""
progressUnpack := ""
statusBar := ""
btnAddBookmark := ""
btnBookmarks := ""

; Подсказки (ToolTip)
tooltipTexts := Map()

; Массивы контролов вкладок
treeControls := []
packControls := []
unpackControls := []
helpControls := []

; История и закладки
folderHistory := []
fileHistory := []
bookmarks := []

; === ЗАГРУЗКА НАСТРОЕК ===
LoadSettings()

; Минимальные размеры
minWidth := 420
minHeight := 380

; Начальные размеры окна
savedWidth := IniRead(iniFile, "Window", "Width", 520)
savedHeight := IniRead(iniFile, "Window", "Height", 420)
if (savedWidth < minWidth)
    savedWidth := minWidth
if (savedHeight < minHeight)
    savedHeight := minHeight

; === СОЗДАНИЕ GUI ===
mainGui := Gui("+Resize +MinSize" minWidth "x" minHeight, APP_NAME " v" APP_VERSION)
mainGui.SetFont("s10", "Segoe UI")
mainGui.BackColor := "F0F0F0"

; Чекбокс "Поверх всех" в правом верхнем углу
chkOnTop := mainGui.Add("CheckBox", "x" (savedWidth - 140) " y5 w120 h20", "Поверх всех")
chkOnTop.Value := alwaysOnTop
chkOnTop.OnEvent("Click", ToggleAlwaysOnTop)

; === TAB CONTROL ===
tabControl := mainGui.Add("Tab3", "x10 y25 w" (savedWidth - 30) " h" (savedHeight - 55), ["Дерево", "Свернуть", "Развернуть", "Справка"])
tabControl.Value := savedTabIndex
tabControl.OnEvent("Change", TabChanged)

; ========== ВКЛАДКА 1: ДЕРЕВО ==========
tabControl.UseTab(1)

; Выпадающий список истории папок
mainGui.Add("Text", "x20 y58 w60 h20", "Папка:")
ddFolderHistory := mainGui.Add("ComboBox", "x80 y55 w" (savedWidth - 260) " h120", folderHistory)
ddFolderHistory.OnEvent("Change", FolderHistoryChanged)
treeControls.Push(ddFolderHistory)
treeControls.Push(mainGui.Add("Text", "x20 y58 w60 h20", "Папка:"))

; Кнопка добавить в закладки
btnAddBookmark := mainGui.Add("Button", "x" (savedWidth - 170) " y54 w50 h24", ICO_ADD_BM)
btnAddBookmark.OnEvent("Click", AddBookmark)
RegisterTooltip(btnAddBookmark, "Добавить текущую папку в закладки")
treeControls.Push(btnAddBookmark)

; Кнопка закладки
btnBookmarks := mainGui.Add("Button", "x" (savedWidth - 115) " y54 w50 h24", ICO_BOOKMARK)
btnBookmarks.OnEvent("Click", ShowBookmarksMenu)
RegisterTooltip(btnBookmarks, "Открыть меню закладок")
treeControls.Push(btnBookmarks)

; Кнопки управления
btnBrowseTree := mainGui.Add("Button", "x20 y84 w90 h28", ICO_FOLDER " Обзор")
btnBrowseTree.OnEvent("Click", BrowseFolder)
RegisterTooltip(btnBrowseTree, "Выбрать папку для сканирования")
treeControls.Push(btnBrowseTree)

btnScanTree := mainGui.Add("Button", "x115 y84 w90 h28", ICO_OPEN " Открыть")
btnScanTree.OnEvent("Click", ScanFolder)
RegisterTooltip(btnScanTree, "Повторно сканировать последнюю папку")
treeControls.Push(btnScanTree)

btnExplorerTree := mainGui.Add("Button", "x210 y84 w100 h28", ICO_EXPLORE " Проводник")
btnExplorerTree.OnEvent("Click", OpenExplorer)
RegisterTooltip(btnExplorerTree, "Открыть папку в Проводнике Windows")
treeControls.Push(btnExplorerTree)

; Кнопки Копировать и Сохранить
btnCopyTree := mainGui.Add("Button", "x20 y118 w110 h28", ICO_COPY " Копировать")
btnCopyTree.OnEvent("Click", CopyTree)
RegisterTooltip(btnCopyTree, "Копировать дерево в буфер обмена")
treeControls.Push(btnCopyTree)

btnSaveTree := mainGui.Add("Button", "x135 y118 w110 h28", ICO_SAVE " Сохранить")
btnSaveTree.OnEvent("Click", SaveTree)
RegisterTooltip(btnSaveTree, "Сохранить дерево в текстовый файл")
treeControls.Push(btnSaveTree)

btnClearTree := mainGui.Add("Button", "x250 y118 w90 h28", ICO_CLEAR " Очистить")
btnClearTree.OnEvent("Click", ClearTree)
RegisterTooltip(btnClearTree, "Очистить поле дерева")
treeControls.Push(btnClearTree)

mainGui.Add("Text", "x20 y150 w340 h2 +0x10")
treeControls.Push(mainGui.Add("Text", "x20 y150 w340 h2 +0x10"))

treeEdit := mainGui.Add("Edit", "x20 y158 w" (savedWidth - 50) " h" (savedHeight - 188) " ReadOnly")
treeEdit.SetFont("s10", "Consolas")
treeEdit.Opt("+BackgroundFFFFFF -E0x200")
treeControls.Push(treeEdit)

; ========== ВКЛАДКА 2: СВЕРНУТЬ ==========
tabControl.UseTab(2)

packControls.Push(mainGui.Add("Text", "x20 y60", "Файл:"))
global ddFileHistory := mainGui.Add("ComboBox", "x60 y58 w" (savedWidth - 240) " h120", fileHistory)
packControls.Push(ddFileHistory)

btnSelectPackFile := mainGui.Add("Button", "x" (savedWidth - 170) " y56 w60 h24", ICO_BROWSE)
btnSelectPackFile.OnEvent("Click", SelectPackFile)
RegisterTooltip(btnSelectPackFile, "Обзор... Выбрать файл для сохранения")
packControls.Push(btnSelectPackFile)

; Прогресс-бар
packControls.Push(mainGui.Add("Text", "x20 y90", "Прогресс:"))
progressPack := mainGui.Add("Progress", "x80 y90 w" (savedWidth - 200) " h20 cGreen")
packControls.Push(progressPack)

packControls.Push(mainGui.Add("Text", "x" (savedWidth - 110) " y90 w80 h20 vPackPercent", "0%"))

btnPackTab := mainGui.Add("Button", "x20 y118 w120 h32", ICO_PACK " Свернуть")
btnPackTab.OnEvent("Click", PackProject)
RegisterTooltip(btnPackTab, "Свернуть проект в один текстовый файл")
packControls.Push(btnPackTab)

; ========== ВКЛАДКА 3: РАЗВЕРНУТЬ ==========
tabControl.UseTab(3)

unpackControls.Push(mainGui.Add("Text", "x20 y60", "Снимок:"))
global ddSnapshotHistory := mainGui.Add("ComboBox", "x80 y58 w" (savedWidth - 260) " h120", fileHistory)
unpackControls.Push(ddSnapshotHistory)

btnSelectSnapshot := mainGui.Add("Button", "x" (savedWidth - 170) " y56 w60 h24", ICO_BROWSE)
btnSelectSnapshot.OnEvent("Click", SelectSnapshotFile)
RegisterTooltip(btnSelectSnapshot, "Обзор... Выбрать файл-снимок")
unpackControls.Push(btnSelectSnapshot)

unpackControls.Push(mainGui.Add("Text", "x20 y88", "Папка:"))
global ddTargetFolder := mainGui.Add("ComboBox", "x80 y86 w" (savedWidth - 260) " h120", folderHistory)
unpackControls.Push(ddTargetFolder)

btnSelectTargetFolder := mainGui.Add("Button", "x" (savedWidth - 170) " y84 w60 h24", ICO_BROWSE)
btnSelectTargetFolder.OnEvent("Click", SelectTargetFolder)
RegisterTooltip(btnSelectTargetFolder, "Обзор... Выбрать папку для разворачивания")
unpackControls.Push(btnSelectTargetFolder)

; Прогресс-бар
unpackControls.Push(mainGui.Add("Text", "x20 y118", "Прогресс:"))
progressUnpack := mainGui.Add("Progress", "x80 y118 w" (savedWidth - 200) " h20 cBlue")
unpackControls.Push(progressUnpack)

unpackControls.Push(mainGui.Add("Text", "x" (savedWidth - 110) " y118 w80 h20 vUnpackPercent", "0%"))

btnUnpackTab := mainGui.Add("Button", "x20 y146 w120 h32", ICO_UNPACK " Развернуть")
btnUnpackTab.OnEvent("Click", UnpackProject)
RegisterTooltip(btnUnpackTab, "Развернуть проект из снимка")
unpackControls.Push(btnUnpackTab)

; ========== ВКЛАДКА 4: СПРАВКА ==========
tabControl.UseTab(4)

global helpEdit := mainGui.Add("Edit", "x20 y60 w" (savedWidth - 50) " h" (savedHeight - 90) " ReadOnly")
helpEdit.SetFont("s10", "Consolas")
helpEdit.Opt("+BackgroundFFFFFF -E0x200")
helpEdit.Value := GetHelpText()
helpControls.Push(helpEdit)

; === СТАТУС ===
global statusBar := mainGui.Add("Text", "x10 y" (savedHeight - 26) " w" (savedWidth - 20), "Готово")

; === СОБЫТИЯ ===
mainGui.OnEvent("Size", GuiSizeChanged)
mainGui.OnEvent("Close", SaveAllAndExit)

; Запускаем таймер подсказок
SetTimer(CheckTooltip, 200)

; === ГОРЯЧИЕ КЛАВИШИ ===
Hotkey "F1", ToggleHelp

; === ПОКАЗАТЬ ===
mainGui.Show("w" savedWidth " h" savedHeight)
mainGui.Title := APP_NAME " v" APP_VERSION " — " tabNames[savedTabIndex]    ; <-- ДОБАВЛЕНО: заголовок с активной вкладкой при старте

; Скрываем контролы неактивных вкладок
TabChanged()

; === ФУНКЦИИ ===

; ---------- ВСПЛЫВАЮЩИЕ ПОДСКАЗКИ (TOOLTIP) ----------
RegisterTooltip(ctrl, text) {
    global tooltipTexts
    tooltipTexts[ctrl.Hwnd] := text
}

CheckTooltip() {
    global tooltipTexts
    
    ; Получаем HWND контрола под курсором
    MouseGetPos(,,, &controlUnderMouse, 2)
    
    ; Проверяем, есть ли подсказка для этого контрола
    if (tooltipTexts.Has(controlUnderMouse)) {
        ToolTip(tooltipTexts[controlUnderMouse])
    } else {
        ToolTip()
    }
}

; ---------- ИСТОРИЯ И ЗАКЛАДКИ ----------
AddToHistory(arr, value, maxItems := MAX_HISTORY) {
    if (value = "" || value = "ERROR")
        return
    newArr := []
    for item in arr {
        if (item != value)
            newArr.Push(item)
    }
    newArr.InsertAt(1, value)
    while (newArr.Length > maxItems)
        newArr.Pop()
    return newArr
}

FolderHistoryChanged(*) {
    global ddFolderHistory, lastFolder
    selected := ddFolderHistory.Text
    if (selected != "" && DirExist(selected)) {
        lastFolder := selected
        SaveSettings()
    }
}

AddBookmark(*) {
    global lastFolder, bookmarks, mainGui
    if (lastFolder = "" || !DirExist(lastFolder)) {
        MsgBox("Сначала выберите папку!", "Закладки", 48)
        return
    }
    for bm in bookmarks {
        if (bm.Path = lastFolder) {
            MsgBox("Эта папка уже в закладках!", "Закладки", 64)
            return
        }
    }
    SplitPath(lastFolder, &folderName)
    bookmarks.Push({Path: lastFolder, Name: folderName})
    SaveSettings()
    MsgBox("Добавлено в закладки:`n" lastFolder, "Закладки", 64)
}

ShowBookmarksMenu(*) {
    global bookmarks, mainGui
    if (bookmarks.Length = 0) {
        MsgBox("Закладок пока нет.`n`nИспользуйте " ICO_ADD_BM " для добавления текущей папки.", "Закладки", 64)
        return
    }
    
    local bmMenu := Menu()
    for index, bm in bookmarks {
        handler := OpenBookmarkAt.Bind(index)
        bmMenu.Add(bm.Name "  (" bm.Path ")", handler)
    }
    bmMenu.Add()
    bmMenu.Add("Очистить все закладки", ClearAllBookmarks)
    bmMenu.Show()
}

OpenBookmarkAt(index, *) {
    global bookmarks, lastFolder, ddFolderHistory
    if (index > bookmarks.Length)
        return
    bm := bookmarks[index]
    if (DirExist(bm.Path)) {
        lastFolder := bm.Path
        ddFolderHistory.Text := bm.Path
        SaveSettings()
        ScanFolder()
    } else {
        if (MsgBox("Папка не найдена:`n" bm.Path "`n`nУдалить из закладок?", "Ошибка", 52) = "Yes") {
            bookmarks.RemoveAt(index)
            SaveSettings()
        }
    }
}

ClearAllBookmarks(*) {
    global bookmarks
    if (MsgBox("Удалить все закладки?", "Подтверждение", 52) = "Yes") {
        bookmarks := []
        SaveSettings()
    }
}

; ---------- ПЕРЕКЛЮЧЕНИЕ ВКЛАДОК ----------
TabChanged(*) {
    global tabControl, treeControls, packControls, unpackControls, helpControls, mainGui, tabNames    ; <-- ДОБАВЛЕНО: mainGui, tabNames
    
    mainGui.Title := APP_NAME " v" APP_VERSION " — " tabNames[tabControl.Value]    ; <-- ДОБАВЛЕНО: обновление заголовка при смене вкладки
    
    for ctrl in treeControls
        ctrl.Visible := false
    for ctrl in packControls
        ctrl.Visible := false
    for ctrl in unpackControls
        ctrl.Visible := false
    for ctrl in helpControls
        ctrl.Visible := false
    
    if (tabControl.Value = 1) {
        for ctrl in treeControls
            ctrl.Visible := true
    } else if (tabControl.Value = 2) {
        for ctrl in packControls
            ctrl.Visible := true
    } else if (tabControl.Value = 3) {
        for ctrl in unpackControls
            ctrl.Visible := true
    } else if (tabControl.Value = 4) {
        for ctrl in helpControls
            ctrl.Visible := true
    }
}

; ---------- ПОСТРОЕНИЕ ДЕРЕВА С КОДИРОВКАМИ ----------
CreateTree(folder, indent := "", isLast := true) {
    result := ""
    items := []
    
    try {
        Loop Files folder . "\*", "FD"
        {
            items.Push(A_LoopFileFullPath)
        }
    } catch {
        return ""
    }
    
    dirs := []
    files := []
    for item in items {
        if InStr(FileExist(item), "D")
            dirs.Push(item)
        else
            files.Push(item)
    }
    
    dirs := SortArray(dirs)
    files := SortArray(files)
    
    allItems := []
    for d in dirs
        allItems.Push({Path: d, IsDir: true})
    for f in files
        allItems.Push({Path: f, IsDir: false})
    
    for index, item in allItems {
        isLastItem := (index = allItems.Length)
        SplitPath(item.Path, &name)
        
        if (item.IsDir) {
            name .= "\"
        } else {
            encoding := DetectEncoding(item.Path)
            if (encoding != "")
                name .= " '" encoding "'"
        }
        
        if (indent = "") {
            result .= (isLastItem ? "└── " : "├── ") . name . "`n"
        } else {
            result .= indent . (isLastItem ? "└── " : "├── ") . name . "`n"
        }
        
        if (item.IsDir) {
            if (indent = "") {
                newIndent := (isLastItem ? "    " : "│   ")
            } else {
                newIndent := indent . (isLastItem ? "    " : "│   ")
            }
            result .= CreateTree(item.Path, newIndent, isLastItem)
        }
    }
    
    return result
}

; ---------- ОПРЕДЕЛЕНИЕ КОДИРОВКИ ----------
DetectEncoding(filePath) {
    try {
        myFile := FileOpen(filePath, "r")
        if !IsObject(myFile)
            return "utf-8"
        
        size := myFile.Length
        if size = 0 {
            myFile.Close()
            return "utf-8"
        }
        
        myBuffer := Buffer(Min(size, 8192))
        myFile.RawRead(myBuffer)
        myFile.Close()
        
        ptr := myBuffer.Ptr
        hasHighBytes := false
        
        Loop myBuffer.Size {
            if NumGet(ptr + A_Index - 1, "UChar") > 127 {
                hasHighBytes := true
                break
            }
        }
        
        if !hasHighBytes
            return "utf-8"
        
        if IsValidUTF8Strict(myBuffer)
            return "utf-8"
        else
            return "cp1251"
            
    } catch {
        return "utf-8"
    }
}

IsValidUTF8Strict(buffer) {
    ptr := buffer.Ptr
    size := buffer.Size
    i := 0
    
    while i < size {
        byte := NumGet(ptr + i, "UChar")
        
        if byte < 128 {
            i++
            continue
        }
        
        if (byte & 0xE0) = 0xC0 {
            seqLen := 2
        } else if (byte & 0xF0) = 0xE0 {
            seqLen := 3
        } else if (byte & 0xF8) = 0xF0 {
            seqLen := 4
        } else {
            return false
        }
        
        Loop seqLen - 1 {
            i++
            if i >= size
                return false
            nextByte := NumGet(ptr + i, "UChar")
            if (nextByte & 0xC0) != 0x80
                return false
        }
        i++
    }
    return true
}

; ---------- СОРТИРОВКА ----------
SortArray(arr) {
    if (arr.Length <= 1)
        return arr
    text := ""
    for item in arr
        text .= item . "`n"
    Sort(text)
    result := []
    sortedLines := StrSplit(RTrim(text, "`n"), "`n")
    for line in sortedLines {
        if (line != "")
            result.Push(line)
    }
    return result
}

; ---------- ЧТЕНИЕ ФАЙЛА В ИСХОДНОЙ КОДИРОВКЕ ----------
ReadFileWithEncoding(filePath, encoding) {
    try {
        switch encoding {
            case "utf-8": return FileRead(filePath, "UTF-8")
            case "cp1251": return FileRead(filePath, "CP1251")
            default: return FileRead(filePath, "UTF-8")
        }
    } catch {
        return ""
    }
}

; ---------- СОХРАНЕНИЕ ФАЙЛА В ОРИГИНАЛЬНОЙ КОДИРОВКЕ ----------
SaveUnpackedFile(baseFolder, relPath, content, encoding) {
    if (SubStr(content, -1) = "`n")
        content := SubStr(content, 1, -1)
    if (SubStr(content, -1) = "`r")
        content := SubStr(content, 1, -1)
    
    fullPath := baseFolder "\" relPath
    dir := RegExReplace(fullPath, "\\[^\\]+$", "")
    if (dir != "" && !DirExist(dir))
        DirCreate(dir)
    
    switch encoding {
        case "utf-8": FileAppend(content, fullPath, "UTF-8")
        case "cp1251": FileAppend(content, fullPath, "CP1251")
        default: FileAppend(content, fullPath, "UTF-8")
    }
}

; ---------- СКАНИРОВАНИЕ ----------
ScanFolder(*) {
    global lastFolder, statusBar, treeEdit, currentTreeRaw, currentTree, ddFolderHistory
    if (lastFolder = "" || !DirExist(lastFolder)) {
        MsgBox("Нет сохранённой папки. Нажмите 'Обзор' для выбора.", "Внимание", 48)
        return
    }
    
    statusBar.Text := "Сканирование: " lastFolder
    tree := lastFolder . "`n" . CreateTree(lastFolder)
    currentTreeRaw := tree
    currentTree := tree
    treeEdit.Value := tree
    UpdateStatusBarCount(tree)
    
    ddFolderHistory.Text := lastFolder
}

BrowseFolder(*) {
    global lastBrowseFolder, lastFolder, statusBar, treeEdit, currentTreeRaw, currentTree, ddFolderHistory, folderHistory
    selectedFolder := DirSelect("", 3, "Выберите папку для отображения")
    if (selectedFolder = "")
        return
    
    lastBrowseFolder := selectedFolder
    lastFolder := selectedFolder
    folderHistory := AddToHistory(folderHistory, selectedFolder)
    ddFolderHistory.Delete()
    for item in folderHistory
        ddFolderHistory.Add([item])
    ddFolderHistory.Text := selectedFolder
    SaveSettings()
    
    statusBar.Text := "Сканирование: " selectedFolder
    tree := selectedFolder . "`n" . CreateTree(selectedFolder)
    currentTreeRaw := tree
    currentTree := tree
    treeEdit.Value := tree
    UpdateStatusBarCount(tree)
}

; ---------- СВОРАЧИВАНИЕ ----------
SelectPackFile(*) {
    global lastFolder, ddFileHistory, fileHistory
    startFolder := lastFolder != "" ? lastFolder : A_Desktop
    file := FileSelect("S", startFolder, "Сохранить снимок", "Текстовые файлы (*.txt)")
    if (file != "") {
        if SubStr(file, -4) != ".txt"
            file .= ".txt"
        fileHistory := AddToHistory(fileHistory, file)
        ddFileHistory.Delete()
        for item in fileHistory
            ddFileHistory.Add([item])
        ddFileHistory.Text := file
        SaveSettings()
    }
}

PackProject(*) {
    global currentTree, statusBar, progressPack, mainGui, fileHistory, ddFileHistory
    if (currentTree = "") {
        MsgBox("Нет дерева для сворачивания.", "Ошибка", 48)
        return
    }
    
    targetFile := ddFileHistory.Text
    if (targetFile = "") {
        MsgBox("Выберите целевой файл.", "Ошибка", 48)
        return
    }
    
    fileHistory := AddToHistory(fileHistory, targetFile)
    ddFileHistory.Delete()
    for item in fileHistory
        ddFileHistory.Add([item])
    ddFileHistory.Text := targetFile
    
    statusBar.Text := "Сворачивание..."
    progressPack.Value := 0
    mainGui["PackPercent"].Text := "0%"
    
    try {
        packedContent := PackFolder(currentTree, progressPack)
        if FileExist(targetFile)
            FileDelete(targetFile)
        FileAppend(packedContent, targetFile, "UTF-8")
        progressPack.Value := 100
        mainGui["PackPercent"].Text := "100%"
        statusBar.Text := "Снимок сохранён: " targetFile
        MsgBox("Снимок успешно создан!", APP_NAME, 64)
    } catch as e {
        MsgBox("Ошибка: " e.Message, "Ошибка", 48)
    } finally {
        SetTimer(() => (progressPack.Value := 0, mainGui["PackPercent"].Text := "0%"), -3000)
    }
}

PackFolder(treeText, progressCtrl := "") {
    result := treeText . "`n`n"
    lines := StrSplit(RTrim(treeText, "`n"), "`n")
    
    rootFolder := Trim(lines[1])
    if (SubStr(rootFolder, -1) = "\")
        rootFolder := SubStr(rootFolder, 1, -1)
    
    files := CollectFilesFromTree(treeText, rootFolder)
    totalFiles := files.Length
    
    if (totalFiles = 0)
        return result
    
    for index, filePath in files {
        relPath := StrReplace(filePath, rootFolder "\", "")
        encoding := DetectEncoding(filePath)
        if (encoding = "")
            continue
        
        fileContent := ReadFileWithEncoding(filePath, encoding)
        if (fileContent = "")
            continue
        
        result .= "=== " relPath " | " encoding " ===`n"
        result .= fileContent
        if (SubStr(fileContent, -1) != "`n")
            result .= "`n"
        result .= "`n"
        
        if (IsObject(progressCtrl)) {
            percent := Round((index / totalFiles) * 100)
            progressCtrl.Value := percent
            mainGui["PackPercent"].Text := percent "%"
        }
    }
    
    return result
}

; ---------- РАЗВОРАЧИВАНИЕ ----------
SelectSnapshotFile(*) {
    global ddSnapshotHistory, fileHistory
    file := FileSelect(1,, "Выберите файл-снимок", "*.txt")
    if (file != "") {
        ddSnapshotHistory.Text := file
        fileHistory := AddToHistory(fileHistory, file)
        ddSnapshotHistory.Delete()
        for item in fileHistory
            ddSnapshotHistory.Add([item])
        ddSnapshotHistory.Text := file
        SaveSettings()
    }
}

SelectTargetFolder(*) {
    global ddTargetFolder, folderHistory
    folder := DirSelect(, 3, "Выберите папку для разворачивания")
    if (folder != "") {
        ddTargetFolder.Text := folder
        folderHistory := AddToHistory(folderHistory, folder)
        ddTargetFolder.Delete()
        for item in folderHistory
            ddTargetFolder.Add([item])
        ddTargetFolder.Text := folder
        SaveSettings()
    }
}

UnpackProject(*) {
    global ddSnapshotHistory, ddTargetFolder, statusBar, progressUnpack, mainGui
    snapshotFile := ddSnapshotHistory.Text
    targetFolder := ddTargetFolder.Text
    
    if (snapshotFile = "" || !FileExist(snapshotFile)) {
        MsgBox("Выберите файл-снимок.", "Ошибка", 48)
        return
    }
    if (targetFolder = "" || !DirExist(targetFolder)) {
        MsgBox("Выберите целевую папку.", "Ошибка", 48)
        return
    }
    
    statusBar.Text := "Разворачивание..."
    progressUnpack.Value := 0
    mainGui["UnpackPercent"].Text := "0%"
    
    try {
        UnpackSnapshot(snapshotFile, targetFolder, progressUnpack)
        progressUnpack.Value := 100
        mainGui["UnpackPercent"].Text := "100%"
        statusBar.Text := "Проект развёрнут в: " targetFolder
        MsgBox("Проект успешно развёрнут!", APP_NAME, 64)
    } catch as e {
        MsgBox("Ошибка: " e.Message, "Ошибка", 48)
    } finally {
        SetTimer(() => (progressUnpack.Value := 0, mainGui["UnpackPercent"].Text := "0%"), -3000)
    }
}

UnpackSnapshot(snapshotFile, targetFolder, progressCtrl := "") {
    content := FileRead(snapshotFile, "UTF-8")
    lines := StrSplit(content, "`n")
    
    currentFile := ""
    currentEncoding := ""
    fileContent := ""
    inFile := false
    
    totalFiles := 0
    for line in lines {
        if RegExMatch(line, "^=== (.+) \| (utf-8|cp1251) ===$")
            totalFiles++
    }
    
    processedFiles := 0
    
    for line in lines {
        if RegExMatch(line, "^=== (.+) \| (utf-8|cp1251) ===$", &match) {
            if (inFile && currentFile != "") {
                SaveUnpackedFile(targetFolder, currentFile, fileContent, currentEncoding)
                processedFiles++
                if (IsObject(progressCtrl)) {
                    percent := Round((processedFiles / totalFiles) * 100)
                    progressCtrl.Value := percent
                    mainGui["UnpackPercent"].Text := percent "%"
                }
            }
            currentFile := match[1]
            currentEncoding := match[2]
            fileContent := ""
            inFile := true
            continue
        }
        
        if (inFile) {
            fileContent .= line . "`n"
        }
    }
    
    if (inFile && currentFile != "") {
        SaveUnpackedFile(targetFolder, currentFile, fileContent, currentEncoding)
        processedFiles++
        if (IsObject(progressCtrl)) {
            percent := Round((processedFiles / totalFiles) * 100)
            progressCtrl.Value := percent
            mainGui["UnpackPercent"].Text := percent "%"
        }
    }
}

; ---------- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ----------
CollectFilesFromTree(treeText, rootFolder) {
    files := []
    lines := StrSplit(RTrim(treeText, "`n"), "`n")
    
    i := 2
    while (i <= lines.Length) {
        line := lines[i]
        if (Trim(line) = "") {
            i++
            continue
        }
        
        clean := RegExReplace(line, "^[│├└─ ]+")
        clean := Trim(clean)
        isFolder := (SubStr(clean, -1) = "\")
        
        if (!isFolder) {
            clean := RegExReplace(clean, " '[^']+'$", "")
            
            pathParts := []
            currentLevel := Floor(StrLen(RegExReplace(line, "^([│├└─ ]+).*$", "$1")) / 4)
            j := i - 1
            
            while (j >= 2) {
                currentLine := lines[j]
                if (Trim(currentLine) = "") {
                    j--
                    continue
                }
                currentLevelLine := Floor(StrLen(RegExReplace(currentLine, "^([│├└─ ]+).*$", "$1")) / 4)
                if (currentLevelLine < currentLevel) {
                    currentClean := RegExReplace(currentLine, "^[│├└─ ]+")
                    currentClean := Trim(currentClean)
                    if (SubStr(currentClean, -1) = "\")
                        currentClean := SubStr(currentClean, 1, -1)
                    pathParts.InsertAt(1, currentClean)
                    currentLevel := currentLevelLine
                }
                j--
            }
            
            fullPath := rootFolder
            for part in pathParts
                fullPath .= "\" . part
            fullPath .= "\" . clean
            
            if (FileExist(fullPath) && !InStr(FileExist(fullPath), "D"))
                files.Push(fullPath)
        }
        i++
    }
    
    return files
}

UpdateStatusBarCount(treeText) {
    global statusBar
    if (treeText = "") {
        statusBar.Text := "Готово"
        return
    }
    
    lines := StrSplit(RTrim(treeText, "`n"), "`n")
    folders := 0
    files := 0
    
    i := 2
    while (i <= lines.Length) {
        line := lines[i]
        if (Trim(line) = "") {
            i++
            continue
        }
        clean := RegExReplace(line, "^[│├└─ ]+")
        clean := Trim(clean)
        if (clean != "") {
            if (SubStr(clean, -1) = "\")
                folders++
            else
                files++
        }
        i++
    }
    
    statusBar.Text := "Папок: " folders " | Файлов: " files " | Всего: " (folders + files)
}

; ---------- GUI ФУНКЦИИ ----------
CopyTree(*) {
    global treeEdit, statusBar
    text := treeEdit.Value
    if (text != "") {
        A_Clipboard := text
        statusBar.Text := "Скопировано в буфер обмена"
        SetTimer(() => UpdateStatusBarCount(treeEdit.Value), -1500)
    }
}

SaveTree(*) {
    global treeEdit, lastSaveFolder, lastFolder, statusBar
    text := treeEdit.Value
    if (text = "") {
        MsgBox("Нет данных для сохранения", "Ошибка", 48)
        return
    }
    
    startFolder := lastSaveFolder != "" ? lastSaveFolder : lastFolder
    file := FileSelect("S", startFolder, "Сохранить дерево как", "*.txt")
    if (file = "")
        return
    
    if (SubStr(file, -4) != ".txt")
        file .= ".txt"
    
    SplitPath(file,, &fileDir)
    lastSaveFolder := fileDir
    SaveSettings()
    
    try {
        FileAppend(text, file, "UTF-8-RAW")
        statusBar.Text := "Сохранено: " file
        SetTimer(() => UpdateStatusBarCount(treeEdit.Value), -2000)
    } catch as e {
        MsgBox("Ошибка: " e.Message, "Ошибка", 48)
    }
}

ClearTree(*) {
    global treeEdit, currentTreeRaw, currentTree, statusBar
    currentTreeRaw := ""
    currentTree := ""
    treeEdit.Value := ""
    statusBar.Text := "Дерево очищено"
}

OpenExplorer(*) {
    global lastFolder, statusBar
    if (lastFolder != "" && DirExist(lastFolder)) {
        Run("explorer.exe `"" lastFolder "`"")
        statusBar.Text := "Открыт проводник"
    } else {
        MsgBox("Нет выбранной папки.", "Ошибка", 48)
    }
}

ToggleAlwaysOnTop(*) {
    global alwaysOnTop, mainGui, chkOnTop
    alwaysOnTop := chkOnTop.Value
    WinSetAlwaysOnTop(alwaysOnTop, mainGui.Hwnd)
    SaveSettings()
}

; ---------- СПРАВКА ----------
ToggleHelp(*) {
    global helpWindow
    if (helpWindow != "" && WinExist("ahk_id " helpWindow)) {
        WinClose("ahk_id " helpWindow)
        helpWindow := ""
    } else {
        ShowHelpWindow()
    }
}

ShowHelpWindow() {
    global helpWindow, APP_NAME, APP_VERSION
    
    helpGui := Gui("+Resize +MinSize400x300", APP_NAME " — Справка")
    helpGui.SetFont("s10", "Segoe UI")
    
    tab := helpGui.Add("Tab3", "x10 y10 w580 h440", ["О программе", "Автор", "Лицензия", "Руководство"])
    
    ; О программе
    tab.UseTab(1)
    txt := helpGui.Add("Edit", "x20 y40 w560 h400 ReadOnly")
    txt.SetFont("s10", "Consolas")
    txt.Opt("+BackgroundFFFFFF -E0x200")
    txt.Value := APP_NAME " v" APP_VERSION "`n`n"
        . "FLS-PLUS (Files Plus) — программа для создания текстовых снимков файловых структур проектов.`n`n"
        . "Автор: IgerOK`n"
        . "GitHub: https://github.com/IgerOK/FLS-PLUS`n`n"
        . "Поддерживаемые кодировки:`n"
        . "• UTF-8`n"
        . "• CP1251 (Windows-1251, кириллица)`n`n"
        . "Возможности:`n"
        . "• Построение псевдографического дерева файлов и папок`n"
        . "• Автоматическое определение кодировок`n"
        . "• Свертывание проекта в один текстовый файл`n"
        . "• Разворачивание проекта из снимка с сохранением кодировок`n"
        . "• История папок и файлов (выпадающие списки)`n"
        . "• Закладки избранных папок`n"
        . "• Прогресс-бар при операциях`n"
        . "• Всплывающие подсказки на кнопках`n`n"
        . "Формат снимка:`n"
        . "=== путь/к/файлу | кодировка ===`n"
        . "содержимое файла`n`n"
        . "Кодировки в снимке: utf-8, cp1251"
    
    ; Автор
    tab.UseTab(2)
    txt2 := helpGui.Add("Edit", "x20 y40 w560 h400 ReadOnly")
    txt2.SetFont("s10", "Consolas")
    txt2.Opt("+BackgroundFFFFFF -E0x200")
    txt2.Value := "Разработчик: IgerOK`n"
        . "GitHub: https://github.com/IgerOK/FLS-PLUS`n"
        . "Год: 2026`n`n"
        . "Благодарности:`n"
        . "• Сообществу AutoHotkey`n"
        . "• Пользователям за обратную связь"
    
    ; Лицензия
    tab.UseTab(3)
    txt3 := helpGui.Add("Edit", "x20 y40 w560 h400 ReadOnly")
    txt3.SetFont("s10", "Consolas")
    txt3.Opt("+BackgroundFFFFFF -E0x200")
    txt3.Value := "MIT License`n`n"
        . "Copyright (c) 2026 IgerOK`n`n"
        . "Permission is hereby granted, free of charge, to any person obtaining a copy`n"
        . "of this software and associated documentation files (the `"Software`"), to deal`n"
        . "in the Software without restriction, including without limitation the rights`n"
        . "to use, copy, modify, merge, publish, distribute, sublicense, and/or sell`n"
        . "copies of the Software, and to permit persons to whom the Software is`n"
        . "furnished to do so, subject to the following conditions:`n`n"
        . "The above copyright notice and this permission notice shall be included in all`n"
        . "copies or substantial portions of the Software.`n`n"
        . "THE SOFTWARE IS PROVIDED `'AS IS'', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR`n"
        . "IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,`n"
        . "FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE`n"
        . "AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER`n"
        . "LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,`n"
        . "OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE`n"
        . "SOFTWARE."
    
    ; Руководство
    tab.UseTab(4)
    txt4 := helpGui.Add("Edit", "x20 y40 w560 h400 ReadOnly")
    txt4.SetFont("s10", "Consolas")
    txt4.Opt("+BackgroundFFFFFF -E0x200")
    txt4.Value := "БЫСТРЫЙ СТАРТ`n`n"
        . "1. Выберите папку (Обзор или выпадающий список истории)`n"
        . "2. Дерево построится автоматически с кодировками`n"
        . "3. Перейдите на вкладку 'Свернуть'`n"
        . "4. Выберите файл и нажмите 'Свернуть'`n`n"
        . "Для разворачивания:`n"
        . "1. Перейдите на вкладку 'Развернуть'`n"
        . "2. Выберите файл-снимок и целевую папку`n"
        . "3. Нажмите 'Развернуть'`n`n"
        . "ЗАГОЛОВОК ОКНА:`n"
        . "При переключении вкладок заголовок окна меняется:`n"
        . "FLS-PLUS v1.0 — Дерево, FLS-PLUS v1.0 — Свернуть и т.д.`n"
        . "Это помогает видеть текущую вкладку в панели задач.`n`n"
        . "ГОРЯЧИЕ КЛАВИШИ:`n"
        . "F1 — Справка`n`n"
        . "В окнах программы работают стандартные сочетания Windows:`n"
        . "Ctrl+A — выделить всё`n"
        . "Ctrl+C — копировать выделенное`n"
        . "Ctrl+Home / Ctrl+End — в начало / конец текста`n"
        . "Page Up / Page Down — прокрутка на страницу`n`n"
        . "ЗАКЛАДКИ:`n"
        . "• " ICO_ADD_BM " — добавить текущую папку в закладки`n"
        . "• " ICO_BOOKMARK " — открыть меню закладок`n`n"
        . "ПОДСКАЗКИ:`n"
        . "При наведении на кнопки появляются всплывающие подсказки`n`n"
        . "Формат снимка:`n"
        . "=== путь/к/файлу | utf-8 ===`n"
        . "=== путь/к/файлу | cp1251 ===`n`n"
    
    tab.UseTab()
    helpGui.Add("Button", "x250 y460 w100", "Закрыть").OnEvent("Click", (*) => helpGui.Destroy())
    
    helpGui.OnEvent("Close", (*) => helpWindow := "")
    helpGui.Show("w600 h500")
    helpWindow := helpGui.Hwnd
}

GetHelpText() {
    return "Нажмите F1 для открытия справки.`n`n"
        . "Кнопки:`n"
        . ICO_FOLDER " Обзор — выбор новой папки`n"
        . ICO_OPEN " Открыть — повторное сканирование`n"
        . ICO_EXPLORE " Проводник — открыть в Explorer`n"
        . ICO_COPY " Копировать — в буфер обмена`n"
        . ICO_SAVE " Сохранить — в .txt файл`n"
        . ICO_CLEAR " Очистить — удалить дерево`n"
        . ICO_ADD_BM " — добавить в закладки`n"
        . ICO_BOOKMARK " — меню закладок`n`n"
        . "Вкладки:`n"
        . "Дерево — просмотр структуры`n"
        . "Свернуть — сохранить проект в снимок`n"
        . "Развернуть — восстановить из снимка`n"
        . "Справка — информация о программе`n`n"
        . "Заголовок окна:`n"
        . "При переключении вкладок заголовок окна меняется:`n"
        . "FLS-PLUS v1.0 — Дерево, FLS-PLUS v1.0 — Свернуть и т.д.`n"
        . "Это помогает видеть текущую вкладку даже при свёрнутом окне.`n`n"
        . "ГОРЯЧИЕ КЛАВИШИ:`n"
        . "F1 — Справка`n`n"
        . "В окнах программы работают стандартные сочетания Windows:`n"
        . "Ctrl+A — выделить всё`n"
        . "Ctrl+C — копировать выделенное`n"
        . "Ctrl+Home / Ctrl+End — в начало / конец текста`n"
        . "Page Up / Page Down — прокрутка на страницу`n`n"
        . "Поддерживаемые кодировки: UTF-8, CP1251`n`n"
        . "Подсказки: при наведении на кнопки появляются подсказки"
}

; ---------- НАСТРОЙКИ ----------
LoadSettings() {
    global iniFile, lastFolder, lastSaveFolder, alwaysOnTop, savedTabIndex
    global folderHistory, fileHistory, bookmarks, MAX_HISTORY, MAX_BOOKMARKS
    
    if FileExist(iniFile) {
        lastFolder := IniRead(iniFile, "Settings", "LastFolder", "")
        lastSaveFolder := IniRead(iniFile, "Settings", "LastSaveFolder", "")
        alwaysOnTop := IniRead(iniFile, "Settings", "AlwaysOnTop", 0)
        savedTabIndex := IniRead(iniFile, "Window", "LastTabIndex", 1)
        
        Loop MAX_HISTORY {
            val := IniRead(iniFile, "FolderHistory", "Item" A_Index, "")
            if (val != "")
                folderHistory.Push(val)
        }
        
        Loop MAX_HISTORY {
            val := IniRead(iniFile, "FileHistory", "Item" A_Index, "")
            if (val != "")
                fileHistory.Push(val)
        }
        
        Loop MAX_BOOKMARKS {
            path := IniRead(iniFile, "Bookmarks", "Path" A_Index, "")
            name := IniRead(iniFile, "Bookmarks", "Name" A_Index, "")
            if (path != "") {
                bookmarks.Push({Path: path, Name: name != "" ? name : path})
            }
        }
    }
}

SaveSettings() {
    global iniFile, lastFolder, lastSaveFolder, alwaysOnTop
    global folderHistory, fileHistory, bookmarks, MAX_HISTORY, MAX_BOOKMARKS
    
    IniWrite(lastFolder, iniFile, "Settings", "LastFolder")
    IniWrite(lastSaveFolder, iniFile, "Settings", "LastSaveFolder")
    IniWrite(alwaysOnTop, iniFile, "Settings", "AlwaysOnTop")
    
    Loop MAX_HISTORY {
        if (A_Index <= folderHistory.Length)
            IniWrite(folderHistory[A_Index], iniFile, "FolderHistory", "Item" A_Index)
        else
            IniDelete(iniFile, "FolderHistory", "Item" A_Index)
    }
    
    Loop MAX_HISTORY {
        if (A_Index <= fileHistory.Length)
            IniWrite(fileHistory[A_Index], iniFile, "FileHistory", "Item" A_Index)
        else
            IniDelete(iniFile, "FileHistory", "Item" A_Index)
    }
    
    Loop MAX_BOOKMARKS {
        if (A_Index <= bookmarks.Length) {
            IniWrite(bookmarks[A_Index].Path, iniFile, "Bookmarks", "Path" A_Index)
            IniWrite(bookmarks[A_Index].Name, iniFile, "Bookmarks", "Name" A_Index)
        } else {
            IniDelete(iniFile, "Bookmarks", "Path" A_Index)
            IniDelete(iniFile, "Bookmarks", "Name" A_Index)
        }
    }
}

SaveAllAndExit(*) {
    global mainGui, tabControl, iniFile
    mainGui.GetClientPos(,, &w, &h)
    IniWrite(w, iniFile, "Window", "Width")
    IniWrite(h, iniFile, "Window", "Height")
    IniWrite(tabControl.Value, iniFile, "Window", "LastTabIndex")
    SaveSettings()
    ExitApp()
}

GuiSizeChanged(gui, minMax, w, h) {
    if (minMax = -1)
        return
    
    global tabControl, treeEdit, helpEdit, statusBar
    global snapshotFileEdit, targetFolderEdit
    global btnSelectPackFile, btnSelectSnapshot, btnSelectTargetFolder
    global chkOnTop, ddFolderHistory, ddFileHistory, ddSnapshotHistory, ddTargetFolder
    global btnAddBookmark, btnBookmarks, progressPack, progressUnpack
    global btnBrowseTree, btnScanTree, btnExplorerTree, btnCopyTree, btnSaveTree, btnClearTree
    global btnPackTab, btnUnpackTab
    
    chkOnTop.Move(w - 140, 5)
    
    tabControl.Move(10, 25, w - 30, h - 55)
    
    ddFolderHistory.Move(80, 55, w - 260)
    btnAddBookmark.Move(w - 170, 54)
    btnBookmarks.Move(w - 115, 54)
    
    treeEdit.Move(20, 158, w - 50, h - 188)
    
    ddFileHistory.Move(60, 58, w - 240)
    btnSelectPackFile.Move(w - 170, 56)
    progressPack.Move(80, 90, w - 200)
    mainGui["PackPercent"].Move(w - 110, 90)
    btnPackTab.Move(20, 118)
    
    ddSnapshotHistory.Move(80, 58, w - 260)
    btnSelectSnapshot.Move(w - 170, 56)
    ddTargetFolder.Move(80, 86, w - 260)
    btnSelectTargetFolder.Move(w - 170, 84)
    progressUnpack.Move(80, 118, w - 200)
    mainGui["UnpackPercent"].Move(w - 110, 118)
    btnUnpackTab.Move(20, 146)
    
    helpEdit.Move(20, 60, w - 50, h - 90)
    
    statusBar.Move(10, h - 26, w - 20)
}