import owlkettle
import std/[sets, options, exitprocs]
import database

viewable App:
  searchQuery: string = ""
  terms: seq[string] = getAllTerms()
  selectedTermIndex: int = -1
  currentDefinition: string = ""
  isEditing: bool = false
  buffer: TextBuffer = newTextBuffer()
  showAbout: bool = false

method view(app: AppState): Widget =
  result = gui:
    Window:
      title = "Albertina"
      defaultSize = (800, 600)

      HeaderBar {.addTitlebar.}:
        MenuButton {.addRight.}:
          icon = "open-menu-symbolic"
          PopoverMenu:
            Box(orient = OrientY, margin = 6, spacing = 6):
              Button:
                text = "About"
                style = [ButtonFlat]
                proc clicked() =
                  discard app.open: gui:
                    AboutDialog:
                      programName = "Albertina"
                      logo = "application-community"
                      version = "0.1.0"
                      credits = @{
                        "Code": @["GatoChalupa", "https://gatochalupa.com"
                        ],
                        "Artwork": @["GatoChalupa"]
                      }


      Grid:
        spacing = 6
        margin = 12
        # Top Search Bar
        Box(orient = OrientX, spacing = 6, margin = 12){.x: 0, y: 0,
            hExpand: true.}:
          Entry:
            text = app.searchQuery
            proc changed(newText: string) =
              app.searchQuery = newText
              if newText == "":
                app.terms = getAllTerms()
              else:
                app.terms = searchTerms(newText)

              app.selectedTermIndex = -1
              let exactMatch = getDefinition(newText)
              if exactMatch.isSome:
                app.currentDefinition = exactMatch.get
                app.isEditing = false
                for i, t in app.terms:
                  if t == newText:
                    app.selectedTermIndex = i
                    break
              else:
                if newText != "":
                  app.isEditing = true
                  app.buffer.text = "" # Clear buffer for new definition
                else:
                  app.isEditing = false
                  app.currentDefinition = ""

        Paned(orient = OrientX) {.x: 0, y: 1, hExpand: true, vExpand: true.}:
          # Left: List of terms
          ScrolledWindow:
            ListBox:
              selectionMode = SelectionSingle
              selected = if app.selectedTermIndex >= 0: [
                app.selectedTermIndex].toHashSet() else: initHashSet[int]()
              proc select(rows: HashSet[int]) =
                if rows.len > 0:
                  for r in rows:
                    app.selectedTermIndex = r
                    let term = app.terms[r]
                    app.searchQuery = term
                    let defOpt = getDefinition(term)
                    if defOpt.isSome:
                      app.currentDefinition = defOpt.get
                      app.isEditing = false
                else:
                  app.selectedTermIndex = -1
                  app.currentDefinition = ""

              for t in app.terms:
                Label(text = t)

          # Right: Details / Edit mode
          Box(orient = OrientY, spacing = 12, margin = 12):
            if app.isEditing and app.searchQuery != "":
              Grid {.expand: true.}:
                spacing = 6
                margin = 12
                Label(text = "Edit definition for: " & app.searchQuery) {.x: 0, y: 0.}
                ScrolledWindow {.x: 0, y: 1, vExpand: true, hExpand: true.}:
                  TextView:
                    buffer = app.buffer
                    editable = true
                Button {.x: 0, y: 2.}:
                  text = "Save"
                  style = [ButtonSuggested]
                  proc clicked() =
                    let defText = app.buffer.text
                    if defText.len > 0:
                      saveDefinition(app.searchQuery, defText)
                      # Refresh
                      app.isEditing = false
                      app.currentDefinition = defText
                      app.terms = searchTerms(app.searchQuery)
                      for i, t in app.terms:
                        if t == app.searchQuery:
                          app.selectedTermIndex = i
                          break
            elif app.selectedTermIndex >= 0 and app.selectedTermIndex < app.terms.len:
              Grid {.expand: true.}:
                spacing = 6
                margin = 12
                Box(orient = OrientX, spacing = 12){.x: 0, y: 0,
                    hExpand: true.}:
                  Label(text = "Term: " & app.terms[app.selectedTermIndex])
                  Button:
                    text = "Edit"
                    proc clicked() =
                      app.isEditing = true
                      app.buffer.text = app.currentDefinition
                  Button:
                    text = "Delete"
                    style = [ButtonDestructive]
                    proc clicked() =
                      deleteTerm(app.terms[app.selectedTermIndex])
                      app.searchQuery = ""
                      app.terms = getAllTerms()
                      app.selectedTermIndex = -1
                      app.currentDefinition = ""
                      app.isEditing = false
                  Button:
                    text = "Close"
                    proc clicked() =
                      app.searchQuery = ""
                      app.terms = getAllTerms()
                      app.selectedTermIndex = -1
                      app.currentDefinition = ""
                      app.isEditing = false
                ScrolledWindow {.x: 0, y: 1, vExpand: true, hExpand: true.}:
                  Label(text = app.currentDefinition, wrap = true)
            else:
              Label(text = "Select a term or search to add a new one.")

initDatabase()
addExitProc(proc() {.noconv.} = closeDatabase())

brew(gui(App()))
