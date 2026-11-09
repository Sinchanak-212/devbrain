"""Terminal-only workspace sidebar and standalone panel entrypoints."""
from __future__ import annotations

import argparse
import asyncio
import json
from pathlib import Path
from uuid import uuid4

from textual import on, work
from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual.screen import ModalScreen
from textual.widgets import Button, DataTable, Footer, Header, Input, Label, Static, Switch

from .config import Settings
from .terminal_safe import plain
from .terminal_ui import BasePanel, ChoiceModal, Field, FormModal, MessageModal


class ConfirmModal(MessageModal):
    def __init__(self, title, value, *, approve="Potwierdź"):
        super().__init__(title, value)
        self.approve = approve

    def compose(self):
        from textual.containers import VerticalScroll
        with Vertical():
            yield Static(plain(self.heading), classes="heading")
            with VerticalScroll():
                text = self.value if isinstance(self.value, str) else json.dumps(self.value, ensure_ascii=False, indent=2)
                yield Static(plain(text))
            with Horizontal(classes="actions"):
                yield Button(self.approve, id="confirm-yes", variant="primary")
                yield Button("Anuluj", id="confirm-no")

    @on(Button.Pressed)
    def confirm_button(self, event):
        event.stop()
        self.dismiss(event.button.id == "confirm-yes")

    def action_close(self):
        self.dismiss(False)


class CredentialModal(ModalScreen[dict | None]):
    """Write-only credential entry; a stored secret is never loaded into this form."""
    CSS = """
    CredentialModal { align: center middle; background: $background 70%; }
    CredentialModal > VerticalScroll { width: 90%; max-width: 100; height: auto; max-height: 95%;
        background: #111a18; border: round #52684b; padding: 1 2; }
    CredentialModal .actions { height: auto; min-height: 3; }
    CredentialModal #credential-error { color: #e7b594; height: auto; }
    """
    BINDINGS = [("escape", "cancel", "Anuluj")]

    def __init__(self, label):
        super().__init__()
        self.profile_label = label

    def compose(self):
        with VerticalScroll():
            yield Static(plain("Klucz — " + self.profile_label), classes="heading")
            yield Static("Klucz pozostaje poza pamięcią projektu. Domyślnie działa tylko podczas bieżącego działania silnika.", markup=False)
            yield Label("Nowy klucz (zapisany klucz nie jest wyświetlany)")
            yield Input(password=True, id="credential-key")
            yield Label("Zapamiętaj lokalnie")
            yield Switch(False, id="credential-persist")
            yield Static("Opcja zapisu tworzy prywatny plik 0600 poza projektem. Plik nie jest szyfrowany i nie trafia do snapshotu.", markup=False)
            yield Static("", id="credential-error", markup=False)
            with Horizontal(classes="actions"):
                yield Button("Ustaw klucz", id="credential-save", variant="primary")
                yield Button("Anuluj", id="credential-cancel")

    @on(Button.Pressed)
    def credential_button(self, event):
        event.stop()
        if event.button.id == "credential-cancel":
            self.action_cancel()
        elif event.button.id == "credential-save":
            key_input = self.query_one("#credential-key", Input)
            value = key_input.value.strip()
            if not value:
                self.query_one("#credential-error", Static).update("Wpisz nowy klucz.")
                return
            persist = self.query_one("#credential-persist", Switch).value
            key_input.value = ""
            self.dismiss({"key": value, "persist": persist})

    def action_cancel(self):
        self.query_one("#credential-key", Input).value = ""
        self.dismiss(None)


def profile_fields(old, *, client, provider=None):
    """Editable forms, with no credential values or opaque JSON blobs."""
    old = old or {}
    fields = [Field("label", "Nazwa profilu", old.get("label", ""), True)]
    if client in {"codex", "claude"}:
        return fields + [Field("client", "Klient: codex / claude", client, True),
                         Field("model", "Model (puste = domyślny klienta)", old.get("model") or "")]
    fields.append(Field("model", "Model" if client == "api" else "Model (puste = domyślny Copilota)", old.get("model") or "", client == "api"))
    if client == "api":
        defaults = {"openai": "https://api.openai.com/v1", "anthropic": "https://api.anthropic.com/v1",
                    "openai_compatible": "http://127.0.0.1:8000/v1", "ollama": "http://127.0.0.1:11434"}
        fields.append(Field("base_url", "Adres API", old.get("base_url") or defaults[provider], True))
    fields.append(Field("credential_ref", "Odwołanie do klucza: env:NAZWA lub profile:ID (puste = bez klucza)", old.get("credential_ref") or ""))
    limits = old.get("limits") or {}
    if client == "api":
        fields += [Field("max_model_calls", "Maksymalna liczba zapytań modelu w turze", str(limits.get("max_model_calls", 20)), True),
                   Field("max_output_tokens", "Maksymalna liczba tokenów odpowiedzi", str(limits.get("max_output_tokens", 4096)), True)]
        if provider == "ollama":
            fields.append(Field("context_window_tokens", "Okno kontekstu Ollamy (tokeny; zużywa RAM/VRAM)", str(limits.get("context_window_tokens", 32768)), True))
    else:
        fields += [Field("max_tool_calls", "Maksymalna liczba narzędzi w turze", str(limits.get("max_tool_calls", 20)), True),
                   Field("max_turn_seconds", "Maksymalny czas tury (sekundy)", str(limits.get("max_turn_seconds", 900)), True)]
    fields.append(Field("command_timeout_seconds", "Limit czasu polecenia (sekundy)", str(limits.get("command_timeout_seconds", 120)), True))
    if client == "api" and provider != "ollama":
        pricing = old.get("pricing") or {}
        fields += [Field("input_per_million", "Cena wejścia USD za milion tokenów (opcjonalnie)", str(pricing.get("input_per_million", ""))),
                   Field("output_per_million", "Cena wyjścia USD za milion tokenów (opcjonalnie)", str(pricing.get("output_per_million", "")))]
    return fields


def profile_from_form(value, *, identifier, client, provider=None):
    row = {"id": identifier, "label": value["label"], "client": client}
    if client in {"codex", "claude"}:
        row.update(client=value["client"], model=value.get("model") or None)
        return row
    if value.get("model"):
        row["model"] = value["model"]
    if value.get("credential_ref"):
        row["credential_ref"] = value["credential_ref"]
    keys = ("max_model_calls", "max_output_tokens", "command_timeout_seconds") if client == "api" else ("max_tool_calls", "max_turn_seconds", "command_timeout_seconds")
    if client == "api" and provider == "ollama":
        keys += ("context_window_tokens",)
    try:
        row["limits"] = {key: int(value[key]) for key in keys}
        if client == "api":
            row.update(provider=provider, base_url=value["base_url"])
            if value.get("input_per_million") or value.get("output_per_million"):
                if not value.get("input_per_million") or not value.get("output_per_million"):
                    raise ValueError("Podaj obie stawki lub pozostaw obie puste.")
                row["pricing"] = {key: float(value[key]) for key in ("input_per_million", "output_per_million")}
    except (ValueError, KeyError) as exc:
        raise ValueError("Podaj poprawne limity całkowite i obie stawki liczbowe albo pozostaw ceny puste.") from exc
    return row


class DiscoveryModal(ModalScreen[dict | None]):
    CSS = """
    DiscoveryModal { align: center middle; background: $background 70%; }
    DiscoveryModal > Vertical { width: 95%; height: 95%; background: #101816; border: round #52684b; padding: 1; }
    DiscoveryModal DataTable { height: 1fr; }
    DiscoveryModal .actions { height: 3; }
    #discovery-notice { height: auto; max-height: 4; }
    """
    BINDINGS = [("escape", "close", "Zamknij")]

    def __init__(self, broker):
        super().__init__()
        self.broker = broker
        self.rows = []

    def compose(self):
        with Vertical():
            yield Static("Projekty z wybranych katalogów", classes="heading")
            yield Static("Skanowanie…", id="discovery-notice", markup=False)
            yield DataTable(id="discovery-rows", cursor_type="row")
            with Horizontal(classes="actions"):
                yield Button("Wybierz", id="discovery-select", variant="primary")
                yield Button("Anuluj skan", id="discovery-cancel")
                yield Button("Zamknij", id="discovery-close")

    def on_mount(self):
        self.query_one("#discovery-rows", DataTable).add_columns("Projekt", "Katalog / pamięć")
        self.set_interval(.7, self.refresh_results)
        self.refresh_results()

    @work(group="discovery-results", exclusive=True, exit_on_error=False)
    async def refresh_results(self):
        try:
            value = await asyncio.to_thread(self.broker.request, "GET", "/api/discovery")
            rows = value.get("candidates", value.get("projects", []))
            self.rows = rows
            table = self.query_one("#discovery-rows", DataTable)
            coordinate = table.cursor_coordinate
            table.clear()
            for index, row in enumerate(rows):
                table.add_row(plain(row.get("name", "Projekt")), plain(str(row.get("root", row.get("path", ""))) + (" · snapshot" if row.get("memory_snapshot") else "")), key=str(index))
            if rows:
                table.move_cursor(row=min(coordinate.row, len(rows)-1))
            self.query_one("#discovery-notice", Static).update(plain(f"{value.get('state', 'unknown')} · {len(rows)} projektów\n" + json.dumps(value.get("errors", []), ensure_ascii=False)))
        except (OSError, ValueError, RuntimeError) as exc:
            self.query_one("#discovery-notice", Static).update(plain(exc))

    def choose(self):
        table = self.query_one("#discovery-rows", DataTable)
        if table.row_count:
            self.dismiss(self.rows[table.cursor_coordinate.row])

    @on(DataTable.RowSelected, "#discovery-rows")
    def row_selected(self):
        self.choose()

    @on(Button.Pressed)
    def discovery_action(self, event):
        event.stop()
        if event.button.id == "discovery-select":
            self.choose()
        elif event.button.id == "discovery-close":
            self.dismiss(None)
        elif event.button.id == "discovery-cancel":
            self.cancel_scan()

    @work(group="discovery-cancel", exit_on_error=False)
    async def cancel_scan(self):
        try:
            await asyncio.to_thread(self.broker.request, "DELETE", "/api/discovery")
            self.refresh_results()
        except (OSError, ValueError, RuntimeError) as exc:
            self.query_one("#discovery-notice", Static).update(plain(exc))

    def action_close(self):
        self.dismiss(None)


class SidebarApp(BasePanel):
    panel_role = "sidebar"
    TITLE = "DevBrain"
    CSS = BasePanel.CSS + """
    #sidebar-main { height: 1fr; padding: 0 1; }
    #sidebar-heading { height: auto; color: #c3df9b; text-style: bold; }
    #project-search { height: 3; }
    #project-rows { height: 1fr; min-height: 4; }
    #sidebar-scope { height: auto; max-height: 3; color: #9aab92; }
    .sidebar-actions { height: 3; }
    .sidebar-actions Button { width: 1fr; min-width: 8; margin-right: 0; padding: 0; }
    """
    BINDINGS = [("w", "work", "Pracuj"), ("p", "inspect", "Podgląd"),
                ("r", "refresh", "Odśwież"), ("m", "memory", "Pamięć")]

    def __init__(self, settings, workspace_id="default", *, broker=None, workspace=None):
        super().__init__(settings, workspace_id, broker=broker, workspace=workspace)
        self.data = {"projects": [], "runs": [], "profiles": [], "settings": {}}
        self.projects = {}
        self._last_render_signature = None

    def compose(self) -> ComposeResult:
        yield Header()
        with Vertical(id="sidebar-main"):
            yield Static("PROJEKTY · lokalne", id="sidebar-heading", markup=False)
            yield Input(placeholder="Szukaj projektu…", id="project-search")
            yield DataTable(id="project-rows", cursor_type="row", show_header=False)
            yield Static("Wybierz projekt", id="sidebar-scope", markup=False)
            with Horizontal(classes="sidebar-actions"):
                yield Button("Pracuj", id="project-work", variant="primary")
                yield Button("Podgląd", id="project-inspect")
            with Horizontal(classes="sidebar-actions"):
                yield Button("Szukaj", id="project-scan")
                yield Button("Dodaj", id="project-add")
            with Horizontal(classes="sidebar-actions"):
                yield Button("Profile", id="profiles-edit")
                yield Button("Panele", id="slots-edit")
            with Horizontal(classes="sidebar-actions"):
                yield Button("Sesje", id="sessions-open")
                yield Button("Loguj", id="auth-open")
            with Horizontal(classes="sidebar-actions"):
                yield Button("Pamięć", id="memory-open")
                yield Button("Import", id="memory-import")
            yield Static("", id="panel-notice", markup=False)
        yield Footer()

    def on_mount(self):
        self.query_one("#project-rows", DataTable).add_column("Projekt")
        self.set_interval(.3, self._poll_workspace)
        self.set_interval(3, self.refresh_sidebar)
        self.start_panel()

    async def ready_panel(self):
        await self.load_state()

    async def workspace_changed(self, value):
        self.query_one("#sidebar-scope", Static).update(plain((value.get("project_name") or "Pamięć globalna") + "\n" + (value.get("worktree") or "")))
        if value.get("launch_errors") or value.get("last_error"):
            self.notice(json.dumps(value.get("launch_errors") or value.get("last_error"), ensure_ascii=False))

    @work(group="sidebar-refresh", exclusive=True, exit_on_error=False)
    async def refresh_sidebar(self):
        try:
            await self.load_state()
        except (OSError, ValueError, RuntimeError) as exc:
            self.notice(exc)

    async def load_state(self):
        value = await self.request("GET", "/api/state")
        self.data = value
        self.projects = {p["id"]: p for p in value.get("projects", [])}
        self.render_projects()

    def render_projects(self):
        table = self.query_one("#project-rows", DataTable)
        selected = self.current_project_id()
        query = self.query_one("#project-search", Input).value.casefold()
        rows = [p for p in self.projects.values() if query in (p["name"] + " " + p["root"]).casefold()]
        signature = json.dumps([(p["id"], p["name"], p["root"]) for p in rows], ensure_ascii=False)
        if signature == self._last_render_signature:
            return
        self._last_render_signature = signature
        table.clear()
        for project in rows:
            table.add_row(plain(project["name"]), key=project["id"])
        if selected:
            for index, project in enumerate(rows):
                if project["id"] == selected:
                    table.move_cursor(row=index)
                    break

    @on(Input.Changed, "#project-search")
    def search_changed(self):
        self._last_render_signature = None
        self.render_projects()

    def current_project_id(self):
        table = self.query_one("#project-rows", DataTable)
        if table.row_count:
            return str(table.coordinate_to_cell_key(table.cursor_coordinate).row_key.value)
        return None

    def chosen_project(self):
        identifier = self.current_project_id() or self.workspace_data.get("project_id")
        project = self.projects.get(identifier)
        if not project:
            raise ValueError("Wybierz projekt z listy.")
        return project

    async def reconcile(self):
        from .workspace import refresh_workspace
        await asyncio.to_thread(refresh_workspace, self.settings, self.workspace_id)
        await self._poll_workspace()

    @work(group="sidebar-select", exclusive=True, exit_on_error=False)
    async def select_project(self, intent):
        try:
            project = self.chosen_project()
            roots = project.get("roots") or [project["root"]]
            selected = self.workspace_data.get("worktree") if self.workspace_data.get("project_id") == project["id"] else project["root"]
            if len(roots) > 1:
                selected = await self.push_screen_wait(ChoiceModal("Katalog pracy", [(r, r) for r in roots]))
                if selected is None:
                    return
            await asyncio.to_thread(self.workspace.select_project, project, selected, intent=intent)
            await self.reconcile()
            current = await asyncio.to_thread(self.workspace.read)
            if current.get("launch_errors") or current.get("last_error"):
                self.notice(json.dumps(current.get("launch_errors") or current.get("last_error"), ensure_ascii=False))
            else:
                self.notice("Wybrano projekt do pracy; stan procesu pokaże panel klienta." if intent == "work" else "Podgląd projektu — bez uruchamiania modeli.")
        except (OSError, ValueError, RuntimeError) as exc:
            self.notice(exc)

    @on(DataTable.RowSelected, "#project-rows")
    def project_row_selected(self):
        self.select_project("work")

    def action_work(self):
        self.select_project("work")

    def action_inspect(self):
        self.select_project("inspect")

    def action_refresh(self):
        self.refresh_sidebar()

    @work(group="sidebar-scan", exclusive=True, exit_on_error=False)
    async def scan_projects(self):
        try:
            roots = self.data.get("settings", {}).get("scan_roots", [])
            value = await self.push_screen_wait(FormModal("Szukaj projektów", [Field("roots", "Jawne katalogi, po jednym w wierszu", "\n".join(roots), True, True)], note="Skanowane są tylko wybrane katalogi. Nie uruchamia to klientów.", submit="Szukaj"))
            if value is None:
                return
            await self.request("POST", "/api/discovery", json={"roots": [r.strip() for r in value["roots"].splitlines() if r.strip()]})
            candidate = await self.push_screen_wait(DiscoveryModal(self.broker))
            if candidate:
                root = candidate.get("root", candidate.get("path"))
                existing = next((p for p in self.projects.values() if p["root"] == root), None)
                if existing:
                    await asyncio.to_thread(self.workspace.select_project, existing, root, intent="inspect")
                    await self.reconcile()
                else:
                    await self.register_project(candidate.get("name") or Path(root).name, root)
        except (OSError, ValueError, RuntimeError) as exc:
            self.notice(exc)

    @work(group="sidebar-register", exclusive=True, exit_on_error=False)
    async def add_project(self):
        value = await self.push_screen_wait(FormModal("Dodaj projekt", [Field("name", "Nazwa projektu", required=True), Field("root", "Istniejący katalog projektu", required=True)], submit="Sprawdź katalog"))
        if value:
            try:
                await self.register_project(value["name"], value["root"])
            except (OSError, ValueError, RuntimeError) as exc:
                self.notice(exc)

    async def register_project(self, name, root):
        inspected = await self.request("POST", "/api/projects/inspect", json={"root": root})
        root = inspected.get("root", root)
        snapshot = inspected.get("memory_snapshot")
        if snapshot:
            choice = await self.push_screen_wait(ChoiceModal("Wykryto przenośną pamięć", [
                ("Sprawdź i wczytaj — zachowaj tożsamość i historię", "import"),
                ("Nowy projekt — osobna tożsamość, bez wczytywania historii", "new")]))
            if choice == "import":
                await self.import_memory_form(snapshot, root, name)
                return
            if choice != "new":
                return
        result = await self.request("POST", "/api/projects", json={"name": name, "root": root})
        project = result.get("project", result)
        await asyncio.to_thread(self.workspace.select_project, project, root, intent="inspect")
        await self.load_state()
        await self.reconcile()
        self.notice("Projekt dodany do podglądu. Pracuj uruchamia klientów jawnie.")

    async def import_memory_form(self, path="", root="", name=""):
        value = await self.push_screen_wait(FormModal("Sprawdź import pamięci", [Field("path", "Snapshot lub manifest.json", path, True), Field("root", "Jawny katalog docelowy", root, True), Field("name", "Nazwa lokalna (opcjonalnie)", name)], note="Wczytanie zachowuje tożsamość projektu. Testy z drugiego komputera pozostają historyczne.", submit="Sprawdź import"))
        if value is None:
            return
        payload = {"path": value["path"], "root": value["root"]}
        if value["name"]:
            payload["name"] = value["name"]
        preview = await self.request("POST", "/api/memory/import", json={**payload, "dry_run": True})
        approve = await self.push_screen_wait(ConfirmModal("Wczytać tę pamięć projektu?", preview, approve="Wczytaj pamięć"))
        if not approve:
            return
        result = await self.request("POST", "/api/memory/import", json={**payload, "dry_run": False})
        project = result.get("project")
        if project:
            await asyncio.to_thread(self.workspace.select_project, project, payload["root"], intent="inspect")
        await self.load_state()
        await self.reconcile()
        self.notice("Pamięć wczytana do podglądu; bez uruchamiania klientów.")

    @work(group="sidebar-import", exclusive=True, exit_on_error=False)
    async def import_memory(self):
        try:
            await self.import_memory_form(root=self.workspace_data.get("worktree") or "")
        except (OSError, ValueError, RuntimeError) as exc:
            self.notice(exc)

    @work(group="sidebar-memory", exclusive=True, exit_on_error=False)
    async def action_memory(self):
        value = {"project_id": self.workspace_data.get("project_id"), "entity_type": "memory", "id": "memory"}
        try:
            await asyncio.to_thread(self.workspace.update, {"selected_entity": value, "focus": "inspector"})
            await self.reconcile()
        except (OSError, ValueError, RuntimeError) as exc:
            self.notice(exc)

    @work(group="sidebar-profiles", exclusive=True, exit_on_error=False)
    async def edit_profiles(self):
        try:
            profiles = self.data.get("profiles", [])
            choice = await self.push_screen_wait(ChoiceModal("Profile klientów i modeli", [(f"{p['label']} · {p.get('provider') or p['client']} · {p.get('model') or 'model domyślny'}", p["id"]) for p in profiles] + [("Dodaj nowy profil", "+")]))
            if choice is None:
                return
            old = next((p for p in profiles if p["id"] == choice), None)
            client = old["client"] if old else None
            provider = old.get("provider") if old else None
            if old is None:
                kind = await self.push_screen_wait(ChoiceModal("Rodzaj połączenia", [
                    ("Codex CLI — logowanie ChatGPT / konfiguracja natywna", "codex"),
                    ("Claude Code — logowanie / konfiguracja natywna", "claude"),
                    ("Ollama — lokalne modele", "ollama"),
                    ("OpenAI API — własny klucz", "openai"),
                    ("Anthropic API — własny klucz", "anthropic"),
                    ("API zgodne z OpenAI — własny adres", "openai_compatible"),
                    ("GitHub Copilot — oficjalny SDK i konto Copilot", "copilot")]))
                if kind is None:
                    return
                client = kind if kind in {"codex", "claude", "copilot"} else "api"
                provider = kind if client == "api" else None
            value = await self.push_screen_wait(FormModal("Profil — " + (provider or client), profile_fields(old, client=client, provider=provider),
                note="Zmiany dotyczą następnego uruchomienia. Sam zapis nie uruchamia modelu. Abonament klienta natywnego, Copilot i rozliczenie API są oddzielne. Klucz ustawisz w Loguj / Połączenia."))
            if value:
                identifier = old["id"] if old else "profile-" + uuid4().hex[:12]
                updated = profile_from_form(value, identifier=identifier, client=client, provider=provider)
                rows = [updated if p["id"] == choice else p for p in profiles]
                if old is None:
                    rows.append(updated)
                await self.request("PUT", "/api/profiles", json={"profiles": rows})
                await self.load_state()
                self.notice("Profil zapisany. Loguj otwiera konfigurację połączenia; Pracuj uruchamia klienta jawnie.")
        except (OSError, ValueError, RuntimeError) as exc:
            self.notice(exc)

    @work(group="sidebar-slots", exclusive=True, exit_on_error=False)
    async def edit_slots(self):
        try:
            settings = self.data.get("settings", {})
            project_id = self.workspace_data.get("project_id")
            choices = [("Domyślny układ", "global")]
            if project_id:
                choices.insert(0, ("Układ tego projektu", "project"))
            scope = await self.push_screen_wait(ChoiceModal("Układ paneli", choices))
            if scope is None:
                return
            slots = settings.get("project_slots", {}).get(project_id, settings.get("default_slots", [])) if scope == "project" else settings.get("default_slots", [])
            catalog = "\n".join(p["id"] + " = " + p["label"] for p in self.data.get("profiles", []))
            value = await self.push_screen_wait(FormModal("Panele klientów", [Field("profiles", "Identyfikatory profili, po jednym w wierszu", "\n".join(s["profile_id"] for s in slots), True, True)], note="Każdy wiersz tworzy panel. Ukrycie zachowuje proces.\n" + catalog))
            if value:
                names = [v.strip() for v in value["profiles"].splitlines() if v.strip()]
                known = {p["id"] for p in self.data.get("profiles", [])}
                if not names or any(n not in known for n in names):
                    raise ValueError("Użyj identyfikatorów istniejących profili.")
                updated = [{"id": slots[index]["id"] if index < len(slots) else "slot-" + uuid4().hex[:12], "profile_id": name} for index, name in enumerate(names)]
                payload = {"default_slots": updated} if scope == "global" else {"project_slots": {**settings.get("project_slots", {}), project_id: updated}}
                await self.request("PUT", "/api/settings", json=payload)
                await self.load_state()
                await self.reconcile()
                self.notice("Układ zapisany. Nowe procesy uruchamiasz przez Pracuj.")
        except (OSError, ValueError, RuntimeError) as exc:
            self.notice(exc)

    @work(group="sidebar-auth", exclusive=True, exit_on_error=False)
    async def login(self):
        try:
            profiles = self.data.get("profiles", [])
            choices = [("Codex CLI — logowanie natywne", "codex"), ("Claude Code — logowanie natywne", "claude")]
            choices += [(p["label"] + " — " + (p.get("provider") or p["client"]), "profile:" + p["id"]) for p in profiles if p.get("client") in {"api", "copilot"}]
            client = await self.push_screen_wait(ChoiceModal("Połączenia i logowanie", choices))
            if not client:
                return
            if client.startswith("profile:"):
                selected = next(p for p in profiles if p["id"] == client.removeprefix("profile:"))
                await self.profile_connection(selected)
                return
            report = await self.request("GET", "/api/auth", params={"client": client})
            approve = await self.push_screen_wait(ConfirmModal("Stan połączenia — " + client, report, approve="Otwórz logowanie"))
            if approve:
                from .workspace import show_auth
                await asyncio.to_thread(show_auth, self.settings, client, self.workspace_id)
                self.notice("Otworzono operacyjny terminal logowania. Nie trafia do pamięci projektu.")
        except (OSError, ValueError, RuntimeError) as exc:
            self.notice(exc)

    async def profile_connection(self, profile):
        identifier = profile["id"]
        choices = [("Stan połączenia — bez generowania odpowiedzi", "status"),
                   ("Lista dostępnych modeli", "models"),
                   ("Sprawdź model i narzędzia — może zużyć limit", "probe"),
                   ("Ustaw / zmień klucz", "credential"), ("Usuń zapisany klucz", "delete")]
        if profile["client"] == "copilot":
            choices += [("Przygotuj runtime Copilota — jawne pobranie", "prepare"),
                        ("Zaloguj do GitHub Copilot", "login")]
        action = await self.push_screen_wait(ChoiceModal("Połączenie — " + profile["label"], choices))
        if action is None:
            return
        base = "/api/profiles/" + identifier
        if action == "credential":
            value = await self.push_screen_wait(CredentialModal(profile["label"]))
            if value is not None:
                await self.request("POST", base + "/credential", json=value)
                value.clear()
                await self.load_state()
                self.notice("Klucz ustawiony. Jego treść nie jest ponownie wyświetlana.")
        elif action == "delete":
            if await self.push_screen_wait(ConfirmModal("Usunąć klucz?", "Dotyczy tylko lokalnego klucza tego profilu.", approve="Usuń klucz")):
                await self.request("DELETE", base + "/credential")
                self.notice("Klucz usunięty.")
        elif action == "probe":
            if await self.push_screen_wait(ConfirmModal("Wykonać test modelu?", "To rzeczywiste zapytanie do wybranego dostawcy. Może zużyć płatne tokeny lub limit Copilota. Test nie edytuje projektu.", approve="Uruchom test")):
                self.notice("Trwa jawny test modelu i obsługi narzędzi…")
                result = await asyncio.to_thread(self.broker.request, "POST", base + "/probe", json={}, timeout=180)
                await self.push_screen_wait(MessageModal("Wynik testu połączenia", result))
        elif action == "prepare":
            if await self.push_screen_wait(ConfirmModal("Przygotować Copilota?", "Pobierze przypięty oficjalny runtime i sprawdzi integralność. Nie uruchamia płatnej inferencji.", approve="Przygotuj")):
                self.notice("Trwa przygotowanie oficjalnego runtime Copilota…")
                result = await asyncio.to_thread(self.broker.request, "POST", "/api/copilot/prepare", json={}, timeout=300)
                await self.push_screen_wait(MessageModal("Przygotowanie Copilota", result))
        elif action == "login":
            result = await self.request("POST", "/api/copilot/login", json={})
            run = result.get("run")
            if run:
                from .workspace import select_run
                await asyncio.to_thread(select_run, self.settings, run["id"], self.workspace_id)
                await self.reconcile()
                self.notice("Otworzono operacyjny terminal logowania Copilota. Dane logowania nie trafiają do pamięci.")
            else:
                await self.push_screen_wait(MessageModal("Logowanie Copilota", result))
        elif action == "models":
            result = await self.request("GET", base + "/models")
            models = result.get("models", [])
            if not models:
                await self.push_screen_wait(MessageModal("Modele", result))
                return
            choice = await self.push_screen_wait(ChoiceModal("Wybierz model — zapis dotyczy następnego uruchomienia", [(m["id"], m["id"]) for m in models]))
            if choice:
                updated = {**profile, "model": choice}
                rows = [updated if p["id"] == identifier else p for p in self.data.get("profiles", [])]
                await self.request("PUT", "/api/profiles", json={"profiles": rows})
                await self.load_state()
                self.notice("Model zapisany; nie uruchomiono generowania odpowiedzi.")
        elif action == "status":
            result = await self.request("GET", base + "/status")
            await self.push_screen_wait(MessageModal("Stan połączenia", result))

    @work(group="sidebar-sessions", exclusive=True, exit_on_error=False)
    async def sessions(self):
        try:
            await self.load_state()
            runs = self.data.get("runs", [])
            choices = [(f"{r.get('client')} · {r.get('lifecycle', r.get('state'))} · {r.get('worktree') or 'logowanie'} · ACK {'tak' if r.get('memory', {}).get('acknowledged') else 'wymagany'}", r["id"]) for r in runs]
            if not choices:
                self.notice("Brak uruchomionych sesji.")
                return
            identifier = await self.push_screen_wait(ChoiceModal("Sesje na tym komputerze", choices))
            if not identifier:
                return
            run = next(r for r in runs if r["id"] == identifier)
            action = await self.push_screen_wait(ChoiceModal("Operacja na sesji", [("Pokaż / dołącz bez nowego procesu", "show"), ("Przejmij sterowanie", "takeover"), ("Przerwij bieżącą operację", "interrupt"), ("Zatrzymaj proces", "stop")] + ([("Wznów zapisaną sesję", "resume"), ("Nowa sesja z pamięcią projektu", "new")] if run.get("project_id") else [])))
            from . import workspace as manager
            if action == "show":
                await asyncio.to_thread(manager.select_run, self.settings, identifier, self.workspace_id)
            elif action == "takeover":
                await asyncio.to_thread(manager.take_control, self.settings, identifier, self.workspace_id)
            elif action == "stop":
                await asyncio.to_thread(manager.stop_run, self.settings, identifier, run.get("generation"), self.workspace_id)
            elif action == "interrupt":
                await self.request("POST", f"/api/client-runs/{identifier}/interrupt", json={"generation": run.get("generation")})
            elif action == "resume":
                await asyncio.to_thread(manager.resume_run, self.settings, identifier, self.workspace_id)
            elif action == "new":
                profile = run.get("profile_id") or run["client"]
                result = await self.request("POST", "/api/client-runs", json={"project": run["project_id"], "worktree": run["worktree"], "slots": [{"id": run["slot_id"], "profile_id": profile}], "resume": False, "idempotency_key": uuid4().hex})
                if result.get("errors"):
                    raise ValueError(json.dumps(result["errors"], ensure_ascii=False))
                if result.get("runs"):
                    await asyncio.to_thread(manager.select_run, self.settings, result["runs"][0]["id"], self.workspace_id)
            await self.reconcile()
            await self.load_state()
        except (OSError, ValueError, RuntimeError) as exc:
            self.notice(str(exc) + " · Nowa sesja jest osobną jawną operacją.")

    @on(Button.Pressed)
    def sidebar_action(self, event):
        actions = {"project-work": self.action_work, "project-inspect": self.action_inspect,
                   "project-scan": self.scan_projects, "project-add": self.add_project,
                   "profiles-edit": self.edit_profiles, "slots-edit": self.edit_slots,
                   "sessions-open": self.sessions, "auth-open": self.login,
                   "memory-open": self.action_memory, "memory-import": self.import_memory}
        action = actions.get(event.button.id)
        if action:
            action()


def main():
    parser = argparse.ArgumentParser(description="Prywatny panel terminalowego środowiska DevBrain")
    parser.add_argument("--kind", choices=["sidebar", "inspector", "graph"], required=True)
    parser.add_argument("--workspace-id", default="default")
    parser.add_argument("--data-dir", type=Path)
    args = parser.parse_args()
    settings = Settings.load(args.data_dir, create=False)
    if args.kind == "sidebar":
        app = SidebarApp(settings, args.workspace_id)
    elif args.kind == "inspector":
        from .terminal_inspector import InspectorApp
        app = InspectorApp(settings, args.workspace_id)
    else:
        from .terminal_graph import GraphApp
        app = GraphApp(settings, args.workspace_id)
    app.run()


if __name__ == "__main__":
    main()
