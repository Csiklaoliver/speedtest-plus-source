#import <Foundation/Foundation.h>

@class SPState;

NS_ASSUME_NONNULL_BEGIN

/// Builds a copy-ready diagnostics snapshot without identifiers, addresses,
/// account data, exact locations, or user-entered identity strings.
FOUNDATION_EXPORT NSString *SPDiagnosticsText(SPState *state);

NS_ASSUME_NONNULL_END
