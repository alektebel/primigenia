"""Generation preserves the reviewed hero and never forks its valley patches."""
import hashlib
import pathlib
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

class StageBuild(unittest.TestCase):
    def test_reuses_hero_without_changing_it(self):
        hero = ROOT / 'web/hero/index.html'
        before = hashlib.sha256(hero.read_bytes()).hexdigest()
        subprocess.run(['python3', 'tools/stage/build_stage.py'], cwd=ROOT, check=True)
        self.assertEqual(before, hashlib.sha256(hero.read_bytes()).hexdigest())
        stage = (ROOT / 'web/stage/index.html').read_text()
        self.assertIn('stage.js', stage)
        self.assertIn('window.__stageEnvironment', stage)
        self.assertNotIn('window.__heroBuild=function', stage)
        for start, end in [('function height(x,z){', '\nconst walkable='),
                           ('function groundY(x,z){', '\nfunction terrainColor(')]:
            original = hero.read_text()
            self.assertEqual(original[original.index(start):original.index(end, original.index(start))],
                             stage[stage.index(start):stage.index(end, stage.index(start))])

if __name__ == '__main__':
    unittest.main()
