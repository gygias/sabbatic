//
//  STMoonController.h
//  Sabbatic
//
//  Created by david on 4/25/25.
//

#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface STMoonController : NSObject

- (id)initWithView:(SCNView *)view;

- (void)doIntroAnimationWithCompletionHandler:(void (^)(void))completionHandler;
- (void)animateToCurrentPhaseWithCompletionHandler:(void (^)(void))completionHandler;

@end

NS_ASSUME_NONNULL_END
