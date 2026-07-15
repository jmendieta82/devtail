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
}
