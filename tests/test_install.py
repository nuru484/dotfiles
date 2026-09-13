"""Offline installer behavior tests using an isolated repository and home."""
from pathlib import Path
import json
import shutil
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1]

class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root/'repo'
        self.home = self.root/'home'
        for name in ['scripts', 'skills', 'claude/skills', 'claude/hooks', 'codex/skills', 'instructions']:
            (self.repo/name).mkdir(parents=True)
        shutil.copy2(SOURCE/'scripts/install-agent.py', self.repo/'scripts/install-agent.py')
        for name in ['claude/CLAUDE.md', 'claude/settings.json', 'codex/AGENTS.md', 'instructions/engineering.md']:
            (self.repo/name).write_text('fixture\n')
        self.skill('skills/common')
        self.skill('claude/skills/claude-memory')
        self.skill('codex/skills/codex-only')

    def skill(self, relative, extra=''):
        p = self.repo/relative
        p.mkdir(parents=True, exist_ok=True)
        (p/'SKILL.md').write_text(f'---\nname: {p.name}\ndescription: A test capability.\n{extra}---\n\n# Instructions\n')
        return p

    def install(self, host='codex', succeeds=True):
        result = subprocess.run([sys.executable, str(self.repo/'scripts/install-agent.py'), host, '--home', str(self.home)], text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, succeeds, result.stderr)
        return result

    def test_shared_and_host_only_isolation(self):
        self.install('claude'); self.install()
        for host in ['.claude', '.agents']:
            self.assertTrue((self.home/host/'skills/common/SKILL.md').is_file())
        self.assertFalse((self.home/'.agents/skills/claude-memory').exists())
        self.assertFalse((self.home/'.claude/skills/codex-only').exists())
        self.assertTrue((self.home/'.codex/AGENTS.md').is_file())
        self.assertTrue((self.home/'.config/dotfiles-agent-instructions/engineering.md').is_file())

    def test_repeat_install_and_source_edits(self):
        self.install()
        self.assertEqual(self.install().stdout, '')
        (self.repo/'skills/common/SKILL.md').write_text((self.repo/'skills/common/SKILL.md').read_text()+'New instruction\n')
        self.assertIn('New instruction', (self.home/'.agents/skills/common/SKILL.md').read_text())

    def test_preserves_existing_files_and_unrelated_skills(self):
        dest=self.home/'.agents/skills/common';dest.mkdir(parents=True)
        (dest/'SKILL.md').write_text('personal content')
        other=self.home/'.agents/skills/unrelated';other.mkdir()
        self.install()
        backup=list(dest.parent.glob('common.pre-dotfiles-*'))
        self.assertEqual(len(backup),1)
        self.assertEqual((backup[0]/'SKILL.md').read_text(),'personal content')
        self.assertTrue(other.is_dir())

    def test_legacy_directory_symlink(self):
        dest=self.home/'.claude/skills';dest.parent.mkdir(parents=True)
        external=self.root/'legacy';external.mkdir()
        (external/'custom').mkdir();(external/'custom/SKILL.md').write_text('custom')
        dest.symlink_to(external)
        self.install('claude')
        self.assertFalse(dest.is_symlink())
        self.assertEqual((dest/'custom/SKILL.md').read_text(),'custom')
        self.assertTrue((external/'custom').is_dir())

    def test_collision_fails_before_writing_home(self):
        self.skill('codex/skills/common')
        self.install(succeeds=False)
        self.assertFalse(self.home.exists())

    def test_invalid_frontmatter_fails_before_writing_home(self):
        (self.repo/'skills/common/SKILL.md').write_text('No frontmatter')
        self.install(succeeds=False)
        self.assertFalse(self.home.exists())

    def test_runtime_specific_skill_is_not_silently_converted(self):
        self.skill('skills/common','context: fork\nagent: Explore\n')
        self.install(succeeds=False)
        self.assertFalse(self.home.exists())

    def test_explicit_only_policy_and_multiline_metadata(self):
        src=self.skill('skills/common','disable-model-invocation: true\nargument-hint: >-\n  file or pattern\n')
        (src/'agents').mkdir();(src/'agents/openai.yaml').write_text('policy:\n  allow_implicit_invocation: false\n')
        (src/'reference.md').write_text('resource')
        self.install()
        target=self.home/'.agents/skills/common'
        text=(target/'SKILL.md').read_text()
        self.assertNotIn('argument-hint',text);self.assertNotIn('file or pattern',text)
        self.assertNotIn('disable-model-invocation',text)
        self.assertIn('allow_implicit_invocation: false',(target/'agents/openai.yaml').read_text())
        self.assertEqual((target/'reference.md').read_text(),'resource')
        self.assertEqual(self.install().stdout,'')
        (src/'SKILL.md').write_text((src/'SKILL.md').read_text()+'Updated\n')
        self.install()
        self.assertIn('Updated',(target/'SKILL.md').read_text())
        self.assertEqual(len(list(target.glob('SKILL.md.pre-dotfiles-*'))),1)

    def test_missing_explicit_only_policy_fails_closed(self):
        self.skill('skills/common','disable-model-invocation: true\n')
        self.install(succeeds=False)
        self.assertFalse(self.home.exists())

class QualityGateTests(unittest.TestCase):
    def test_node_success_failure_and_non_node(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            subprocess.run(['git','init','-q',tmp],check=True)
            def gate():
                return subprocess.run(['bash',str(SOURCE/'git/hooks/quality-gate.sh')],cwd=root,text=True,capture_output=True)
            self.assertEqual(gate().returncode,0)
            p=root/'package.json'
            p.write_text(json.dumps({'scripts':{'lint':'node -e "process.exit(0)"','test':'node -e "process.exit(1)"'}}))
            self.assertNotEqual(gate().returncode,0)
            p.write_text(json.dumps({'scripts':{'lint':'node -e "process.exit(0)"'}}))
            self.assertEqual(gate().returncode,0)

if __name__ == '__main__':
    unittest.main()
