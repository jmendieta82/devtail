import Testing
@testable import Devtail

struct ShellCommandTests {
    @Test func userShellReadsSHELLFromEnvironment() {
        #expect(ShellCommand.userShell(environment: ["SHELL": "/opt/homebrew/bin/fish"]) == "/opt/homebrew/bin/fish")
    }

    @Test func userShellFallsBackToZsh() {
        #expect(ShellCommand.userShell(environment: [:]) == "/bin/zsh")
    }

    @Test func loginShellInvocationWrapsCommandWithILC() {
        let inv = ShellCommand.loginShellInvocation(command: "npm run dev", shell: "/bin/zsh")
        #expect(inv == ["/bin/zsh", "-ilc", "npm run dev"])
    }

    @Test func loginShellInvocationWithoutCommandIsInteractiveLogin() {
        #expect(ShellCommand.loginShellInvocation(command: nil, shell: "/bin/zsh") == ["/bin/zsh", "-il"])
        #expect(ShellCommand.loginShellInvocation(command: "  ", shell: "/bin/zsh") == ["/bin/zsh", "-il"])
    }

    @Test func commandWithQuotesPassesThroughUntouched() {
        // Args go to execv as an array — no shell re-quoting of our own.
        let inv = ShellCommand.loginShellInvocation(command: #"echo "hola mundo""#, shell: "/bin/zsh")
        #expect(inv[2] == #"echo "hola mundo""#)
    }

    @Test func sessionEnvironmentInheritsBaseAndOverlaysTerm() {
        let env = ShellCommand.sessionEnvironment(
            base: ["PATH": "/opt/homebrew/bin:/usr/bin", "HOME": "/Users/x", "SHELL": "/bin/zsh", "LANG": "es_CO.UTF-8"],
            termName: "xterm-256color"
        )
        #expect(env.contains("PATH=/opt/homebrew/bin:/usr/bin"))
        #expect(env.contains("HOME=/Users/x"))
        #expect(env.contains("SHELL=/bin/zsh"))
        #expect(env.contains("TERM=xterm-256color"))
        #expect(env.contains("COLORTERM=truecolor"))
        // Existing LANG wins over the fallback.
        #expect(env.contains("LANG=es_CO.UTF-8"))
        #expect(!env.contains("LANG=en_US.UTF-8"))
    }

    @Test func sessionEnvironmentAddsLangFallbackWhenMissing() {
        let env = ShellCommand.sessionEnvironment(base: [:], termName: "xterm-256color")
        #expect(env.contains("LANG=en_US.UTF-8"))
    }
}
