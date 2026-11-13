#!/usr/bin/python3
"""Tests for kiln-agent-status: which hook event gives which colour. Uses a temp folder."""
import importlib.machinery
import importlib.util
import os
import tempfile
import unittest

HERE = os.path.dirname(os.path.realpath(__file__))
PATH = os.path.join(HERE, "..", "..", "scripts", "kiln-agent-status")
loader = importlib.machinery.SourceFileLoader("kiln_agent_status", PATH)
spec = importlib.util.spec_from_loader("kiln_agent_status", loader)
s = importlib.util.module_from_spec(spec)
loader.exec_module(s)


class Events(unittest.TestCase):
    def setUp(self):
        s.DIR = tempfile.mkdtemp()

    def state(self, event):
        found = s.from_hook(event)
        if found:
            s.write(*found)
        return found and found[:2]

    def test_operator_working_then_idle(self):
        self.assertEqual(self.state({"hook_event_name": "UserPromptSubmit"}), ("operator", "working"))
        self.assertEqual(self.state({"hook_event_name": "Stop"}), ("operator", "idle"))

    def test_operator_needs_you(self):
        for e in ({"hook_event_name": "PermissionRequest"},
                  {"hook_event_name": "PreToolUse", "tool_name": "AskUserQuestion"},
                  {"hook_event_name": "Notification", "notification_type": "permission_prompt"},
                  {"hook_event_name": "StopFailure", "error": "overloaded"}):
            self.assertEqual(self.state(e), ("operator", "alert"), e)

    def test_answer_clears_red(self):
        self.state({"hook_event_name": "PermissionRequest"})
        self.assertEqual(self.state({"hook_event_name": "PostToolUse"}), ("operator", "working"))

    def test_idle_prompt_after_interrupt(self):
        self.state({"hook_event_name": "UserPromptSubmit"})
        self.assertEqual(self.state({"hook_event_name": "Notification",
                                     "notification_type": "idle_prompt"}), ("operator", "idle"))

    def test_idle_prompt_keeps_red(self):
        self.state({"hook_event_name": "PermissionRequest"})
        self.assertIsNone(self.state({"hook_event_name": "Notification",
                                      "notification_type": "idle_prompt"}))
        self.assertEqual(s.read("operator")[0], "alert")

    def test_helpers(self):
        self.assertEqual(self.state({"hook_event_name": "SubagentStart", "agent_type": "researcher"}),
                         ("researcher", "working"))
        self.assertEqual(self.state({"hook_event_name": "PreToolUse", "tool_name": "Read",
                                     "agent_type": "reviewer"}), ("reviewer", "working"))
        self.assertEqual(self.state({"hook_event_name": "SubagentStop", "agent_type": "researcher",
                                     "last_assistant_message": "Answer."}), ("researcher", "idle"))

    def test_helper_tool_calls_leave_operator_alone(self):
        self.state({"hook_event_name": "Stop"})
        self.state({"hook_event_name": "PreToolUse", "tool_name": "Read", "agent_type": "researcher"})
        self.assertEqual(s.read("operator")[0], "idle")

    def test_reviewer_verdicts(self):
        stop = {"hook_event_name": "SubagentStop", "agent_type": "reviewer"}
        for text, want in (("VERDICT: GO\nFine.", "idle"), ("VERDICT: CONCERNS\n1. x", "alert"),
                           ("VERDICT: STOP\nNo.", "alert")):
            self.assertEqual(self.state(dict(stop, last_assistant_message=text))[1], want, text)

    def test_other_helpers_not_shown(self):
        self.assertIsNone(self.state({"hook_event_name": "SubagentStart", "agent_type": "Explore"}))
        self.assertIsNone(self.state({"hook_event_name": "PreToolUse", "agent_type": "general-purpose"}))

    def test_watcher(self):
        report = os.path.join(s.DIR, "latest.txt")
        s.WATCH_REPORT = report
        with open(report, "w") as f:
            f.write("Kiln watch, 2026-11-13 18:00: all well.\n")
        s.watcher_done()
        self.assertEqual(s.read("watcher")[0], "idle")
        with open(report, "w") as f:
            f.write("Kiln watch, 2026-11-13 18:00: 2 things need attention.\n")
        s.watcher_done()
        self.assertEqual(s.read("watcher"), ("alert", s.stamp("2 things need attention.")))
        os.environ["SERVICE_RESULT"] = "exit-code"
        try:
            s.watcher_done()
        finally:
            del os.environ["SERVICE_RESULT"]
        self.assertEqual(s.read("watcher")[0], "alert")


if __name__ == "__main__":
    unittest.main()
