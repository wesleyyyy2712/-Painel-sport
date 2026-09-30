import Foundation

/// Resultado explícito da investigação de execução. Esta camada não executa código.
enum GuestExecutionStatus: Equatable, Sendable {
    case blocked(reason: String)
    case notImplemented(reason: String)
}

struct GuestExecutionAssessment: Equatable, Sendable {
    let status: GuestExecutionStatus
    let restrictions: [String]
}

protocol GuestExecutionBoundary: Sendable {
    func assess() -> GuestExecutionAssessment
}

/// No ambiente normal do iOS, o Guest Runtime permanece estrutural.
/// Não há tentativa de iniciar MH_EXECUTE, criar processo, fazer dlopen,
/// alterar memória executável ou contornar assinatura/sandbox.
struct IOSStructuralExecutionBoundary: GuestExecutionBoundary {
    func assess() -> GuestExecutionAssessment {
        GuestExecutionAssessment(
            status: .blocked(reason: "iOS não permite executar um MH_EXECUTE arbitrário como guest dentro do processo assinado sem uma arquitetura de execução e assinatura compatíveis."),
            restrictions: [
                "todo código executável precisa de assinatura Apple válida",
                "bibliotecas vinculadas ao processo estão sujeitas à validação de assinatura e Team ID",
                "o sandbox não concede um processo guest arbitrário ao aplicativo",
                "não é permitido contornar assinatura, entitlements ou sandbox",
                "esta implementação não usa APIs de execução, injeção ou carregamento dinâmico"
            ]
        )
    }
}
