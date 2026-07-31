import Foundation
import NetworkExtension

// System Extension — в отличие от App Extension (appex, грузится in-process
// расширяемым приложением через NSExtensionPrincipalClass), это отдельный
// исполняемый файл, который launchd запускает как самостоятельный процесс —
// поэтому ему, как обычному Mach-O executable, нужна настоящая точка входа
// `main`, а не только NSExtensionPrincipalClass в Info.plist. Обнаружено
// реальной линковкой ("_main", referenced from: <initial-undefines>") —
// `NEProvider.startSystemExtensionMode()` — документированный Apple API
// именно для этого сценария (см. NetworkExtension framework, System
// Extension lifecycle).
autoreleasepool {
  NEProvider.startSystemExtensionMode()
}

dispatchMain()
