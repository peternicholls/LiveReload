
#import "RunTestsAction.h"
#import "ScriptInvocationStep.h"
#import "Project.h"
#import "LRTestRunner.h"
#import "LiveReload-Swift-x.h"
#import "LROperationResult.h"


@interface RunTestsAction ()

@end


@implementation RunTestsAction

- (NSString *)label {
    return self.type.name;
}

- (void)invokeWithModifiedFiles:(NSArray *)files result:(LROperationResult *)result completionHandler:(dispatch_block_t)completionHandler {
    if (!self.effectiveVersion) {
        [result completedWithInvocationError:[self missingEffectiveVersionError]];
        return completionHandler();
    }

    LRTRRun *run = [[LRTRRun alloc] init];
    LRTRProtocolParser *parser = [[LRTRTestAnythingProtocolParser alloc] init];
    parser.delegate = run;

    ScriptInvocationStep *step = [ScriptInvocationStep new];
    step.result = result;
    [self configureStep:step];

    step.completionHandler = ^(ScriptInvocationStep *step) {
        [parser finish];
        NSLog(@"Tests = %@", run.tests);
//        [self didCompleteCompilationStep:step forFile:file];
        completionHandler();
    };

    step.outputLineBlock = ^(NSString *line) {
        NSLog(@"Testing output line: %@", [line stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]]);
        [parser processLine:line];
    };

    NSLog(@"%@: %@", self.label, self.project.rootURL.path);
    [step invoke];
}

- (LRTarget *)targetForModifiedFiles:(NSArray *)files {
    if ([self inputPathSpecMatchesFiles:files]) {
        return [[LRProjectTarget alloc] initWithAction:self modifiedFiles:files];
    } else {
        return nil;
    }
}

@end