//
//  SDClientProxy.m
//  Zephyros
//
//  Created by Steven Degutis on 8/12/13.
//  Copyright (c) 2013 Giant Robot Software. All rights reserved.
//

#import "SDClientProxy.h"

#import "SDLogWindowController.h"

@implementation SDClientProxy

//- (void) check:(NSArray*)args forTypes:(NSArray*)types inMethod:(SEL)method {
//    int i = 0;
//    for (Class klass in types) {
//        id arg = [args objectAtIndex:i];
//        if (![arg isKindOfClass:klass]) {
//            NSString* error = [NSString stringWithFormat:@"API Error: in method [%@] on object of type [%@], argument %d was expected to be type %@ but was %@", NSStringFromSelector(method), [self className], i, klass, [arg className]];
//            [[SDLogWindowController sharedLogWindowController] show:error
//                                                               type:SDLogMessageTypeError];
//            
//            return nil;
//        }
//        
//        i++;
//    }
//}

@end