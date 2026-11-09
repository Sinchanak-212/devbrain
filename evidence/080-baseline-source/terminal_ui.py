"""Shared literal-text controls for terminal-only workspace panels."""
from __future__ import annotations

import asyncio
import json
import os
from contextlib import suppress
from dataclasses import dataclass

from textual import on, work
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual.screen import ModalScreen
from textual.widgets import Button, Footer, Header, Input, Label, Static, TextArea
from textual.worker import WorkerState

from .terminal_safe import plain, safe_text


async def wide_dialog(app, screen, role, open_screen):
    """Temporarily zoom a real workspace pane; preserve explicit user changes."""
    if getattr(app, "is_headless", False) or not os.environ.get("TMUX_PANE"):
        return await open_screen(screen)
    from .workspace import refresh_workspace
    before = await asyncio.to_thread(app.workspace.read)
    changed = (before.get("focus"), before.get("zoom", False)) != (role, True)
    applied = False
    try:
        if changed:
            await asyncio.to_thread(app.workspace.update, {"focus": role, "zoom": True})
            applied = True
            await asyncio.to_thread(refresh_workspace, app.settings, app.workspace_id)
            await asyncio.sleep(.08)
        return await open_screen(screen)
    finally:
        if applied:
            current = await asyncio.to_thread(app.workspace.read)
            if (current.get("focus"), current.get("zoom")) == (role, True):
                await asyncio.to_thread(app.workspace.update, {"focus": before.get("focus", role), "zoom": before.get("zoom", False)})
                await asyncio.to_thread(refresh_workspace, app.settings, app.workspace_id)


@dataclass(frozen=True)
class Field:
    name: str
    label: str
    value: str = ""
    required: bool = False
    multiline: bool = False


class FormModal(ModalScreen[dict | None]):
    CSS = """
    FormModal { align: center middle; background: $background 70%; }
    FormModal > VerticalScroll { width: 88%; max-width: 100; height: auto; max-height: 95%;
        border: round #52684b; background: #111a18; padding: 1 2; }
    FormModal .form-title { text-style: bold; color: #c3df9b; height: auto; margin-bottom: 1; }
    FormModal .form-label { height: auto; margin-top: 1; }
    FormModal TextArea { height: 7; }
    FormModal .form-actions { height: 3; margin-top: 1; }
    FormModal .form-actions Button { margin-right: 1; }
    FormModal #form-error { height: auto; color: #e7b594; }
    """
    BINDINGS = [("escape", "cancel", "Anuluj")]

    def __init__(self, title: str, fields: list[Field], *, note: str = "", submit="Zapisz"):
        super().__init__()
        self.title_text, self.fields, self.note, self.submit_label = title, fields, note, submit

    def compose(self) -> ComposeResult:
        with VerticalScroll():
            yield Static(plain(self.title_text), classes="form-title")
            if self.note:
                yield Static(plain(self.note))
            for field in self.fields:
                yield Label(plain(field.label), classes="form-label")
                if field.multiline:
                    yield TextArea(field.value, id="field-" + field.name)
                else:
                    yield Input(field.value, id="field-" + field.name)
            yield Static("", id="form-error", markup=False)
            with Horizontal(classes="form-actions"):
                yield Button(self.submit_label, id="form-submit", variant="primary")
                yield Button("Anuluj", id="form-cancel")

    @on(Button.Pressed)
    def form_button(self, event: Button.Pressed) -> None:
        event.stop()
        if event.button.id == "form-cancel":
            self.dismiss(None)
        elif event.button.id == "form-submit":
            values = {}
            for field in self.fields:
                widget = self.query_one("#field-" + field.name)
                value = widget.text if isinstance(widget, TextArea) else widget.value
                if field.required and not value.strip():
                    self.query_one("#form-error", Static).update(plain("Uzupełnij: " + field.label))
                    return
                values[field.name] = value.strip()
            self.dismiss(values)

    def action_cancel(self) -> None:
        self.dismiss(None)


class MessageModal(ModalScreen[None]):
    CSS = """
    MessageModal { align: center middle; background: $background 70%; }
    MessageModal > Vertical { width: 90%; max-width: 120; height: 90%; border: round #52684b;
      background: #111a18; padding: 1 2; }
    MessageModal VerticalScroll { height: 1fr; }
    MessageModal Button { margin-top: 1; }
    """
    BINDINGS = [("escape", "close", "Zamknij")]

    def __init__(self, title: str, value):
        super().__init__()
        self.heading = title
        self.value = value

    def compose(self) -> ComposeResult:
        with Vertical():
            yield Static(plain(self.heading), classes="heading")
            with VerticalScroll():
                text = self.value if isinstance(self.value, str) else json.dumps(self.value, ensure_ascii=False, indent=2)
                yield Static(plain(text), id="message-body")
            yield Button("Zamknij", id="message-close")

    @on(Button.Pressed, "#message-close")
    def close_button(self) -> None:
        self.dismiss(None)

    def action_close(self) -> None:
        self.dismiss(None)


class BasePanel(App):
    CSS = """
    Screen { background: #101816; color: #d4dfd3; }
    Header { height: 1; background: #1c2a20; color: #c3df9b; }
    Footer { background: #1c2a20; }
    Button { min-width: 10; border: tall #344834; margin-right: 1; }
    Button.-primary { background: #365138; color: #d8edc7; }
    Input, TextArea { border: tall #344834; background: #101a15; }
    Select { border: none; background: #101a15; }
    SelectCurrent { border: tall #344834; background: #101a15; }
    DataTable { background: #101816; }
    .heading { color: #c3df9b; text-style: bold; height: auto; }
    .actions { height: auto; min-height: 3; }
    #panel-notice { height: auto; max-height: 5; color: #dcb78c; padding: 0 1; }
    """

    def __init__(self, settings, workspace_id="default", *, broker=None, workspace=None):
        super().__init__()
        from .terminal_client import BrokerClient
        from .workspace_state import WorkspaceState
        self.settings = settings
        self.workspace_id = workspace_id
        self.broker = broker if broker is not None else BrokerClient(settings, ensure=False)
        self.workspace = workspace if workspace is not None else WorkspaceState(settings, workspace_id)
        self.workspace_data = {}
        self._scope_version = 0
        self._workspace_revision = None

    async def push_screen_wait(self, screen):
        return await wide_dialog(self, screen, getattr(self, "panel_role", "inspector"), super().push_screen_wait)

    async def request(self, method, path, *, params=None, json=None):
        return await asyncio.to_thread(self.broker.request, method, path, params=params, json=json)

    def notice(self, value) -> None:
        with suppress(Exception):
            self.query_one("#panel-notice", Static).update(plain(value))

    async def workspace_changed(self, value: dict) -> None:
        """Subclass refreshes its projection when the local view changes."""

    async def _poll_workspace(self) -> None:
        try:
            value = await asyncio.to_thread(self.workspace.read)
            revision = value.get("revision")
            if revision != self._workspace_revision:
                old = self.workspace_data
                self._workspace_revision = revision
                self.workspace_data = value
                if (old.get("project_id"), old.get("worktree")) != (value.get("project_id"), value.get("worktree")):
                    self._scope_version += 1
                await self.workspace_changed(value)
        except (OSError, ValueError, RuntimeError) as exc:
            self.notice(safe_text(exc))

    @work(group="panel-startup", exclusive=True, exit_on_error=False)
    async def start_panel(self):
        try:
            await asyncio.to_thread(self.broker.ensure)
            await self._poll_workspace()
            await self.ready_panel()
        except (OSError, ValueError, RuntimeError) as exc:
            self.notice(safe_text(exc))

    async def ready_panel(self):
        pass

    def on_unmount(self):
        with suppress(Exception):
            self.workers.cancel_all()

    def on_worker_state_changed(self, event):
        if event.state == WorkerState.ERROR:
            self.notice("Operacja nie została ukończona: " + safe_text(event.worker.error))

    def header_footer(self):
        yield Header()
        yield Footer()


class ChoiceModal(ModalScreen[str | None]):
    CSS = """
    ChoiceModal { align: center middle; background: $background 70%; }
    ChoiceModal > Vertical { width: 90%; max-width: 110; height: 85%; padding: 1 2;
      background: #111a18; border: round #52684b; }
    ChoiceModal DataTable { height: 1fr; }
    """
    BINDINGS = [("escape", "cancel", "Anuluj")]

    def __init__(self, title, choices):
        super().__init__()
        self.heading, self.choices = title, choices

    def compose(self):
        from textual.widgets import DataTable
        with Vertical():
            yield Static(plain(self.heading), classes="heading")
            yield DataTable(id="choices", cursor_type="row")
            yield Button("Anuluj", id="choice-cancel")

    def on_mount(self):
        from textual.widgets import DataTable
        table = self.query_one("#choices", DataTable)
        table.add_column("Wybierz")
        for index, (title, _) in enumerate(self.choices):
            table.add_row(plain(title), key=str(index))
        table.focus()

    @on(Button.Pressed, "#choice-cancel")
    def cancel_button(self):
        self.dismiss(None)

    def action_cancel(self):
        self.dismiss(None)

    def on_data_table_row_selected(self, event):
        if event.data_table.id == "choices":
            self.dismiss(self.choices[int(event.row_key.value)][1])
