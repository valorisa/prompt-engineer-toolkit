# PromptOps Console Tests - Pester 5+
BeforeAll {
    $ScriptPath = "$PSScriptRoot/../scripts/PromptOpsConsole.ps1"
}

Describe "PromptOpsConsole.ps1" {
    It "Should exist" {
        $ScriptPath | Should -Exist
    }

    It "Should return version with -Version flag" {
        $output = & $ScriptPath -Version
        $output.ToString().Trim() | Should -Match "^\d+\.\d+\.\d+$"
    }
}

# TODO(v2): Add integration tests for menu navigation.