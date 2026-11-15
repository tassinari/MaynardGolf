"""Unit tests for scripts/simulator.py (#97)."""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import simulator  # noqa: E402

DEVICES = {
    "com.apple.CoreSimulator.SimRuntime.iOS-26-4": [
        {"name": "iPhone 17", "udid": "A-26-4", "state": "Shutdown", "isAvailable": True}],
    "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
        {"name": "iPhone 17", "udid": "B-26-5", "state": "Shutdown", "isAvailable": True},
        {"name": "iPhone 17", "udid": "C-26-5-booted", "state": "Booted", "isAvailable": True},
        {"name": "iPhone 17 Pro", "udid": "D-26-5", "state": "Shutdown", "isAvailable": True}],
    "com.apple.CoreSimulator.SimRuntime.iOS-27-0": [
        {"name": "iPhone 17", "udid": "E-27", "state": "Shutdown", "isAvailable": True}],
    "com.apple.CoreSimulator.SimRuntime.watchOS-12-0": [
        {"name": "iPhone 17", "udid": "W", "state": "Shutdown", "isAvailable": True}],
}


class SimulatorTests(unittest.TestCase):
    def test_newest_runtime_of_the_major_version_and_booted_first(self):
        self.assertEqual(simulator.pick(DEVICES, "iPhone 17", "26"), "C-26-5-booted")

    def test_an_exact_minor_version(self):
        self.assertEqual(simulator.pick(DEVICES, "iPhone 17", "26.4"), "A-26-4")

    def test_other_device_names_and_platforms_are_ignored(self):
        self.assertEqual(simulator.pick(DEVICES, "iPhone 17 Pro", "26"), "D-26-5")
        self.assertIsNone(simulator.pick(DEVICES, "iPhone 17 Pro", "27"))

    def test_any_os_takes_the_newest_runtime_with_the_device(self):
        self.assertEqual(simulator.pick(DEVICES, "iPhone 17", "any"), "E-27")
        self.assertEqual(simulator.pick(DEVICES, "iPhone 17 Pro", "any"), "D-26-5")

    def test_runtime_version_parsing(self):
        self.assertEqual(simulator.runtime_version("com.apple.CoreSimulator.SimRuntime.iOS-26-4"), (26, 4))
        self.assertIsNone(simulator.runtime_version("com.apple.CoreSimulator.SimRuntime.watchOS-12-0"))


if __name__ == "__main__":
    unittest.main()
