/* Copyright Urban Airship and Contributors */

#import "UAirshipPlugin.h"
#import "UAMessageViewController.h"
#import "UACordovaPluginManager.h"

typedef void (^UACordovaCompletionHandler)(CDVCommandStatus, id);
typedef void (^UACordovaExecutionBlock)(NSArray *args, UACordovaCompletionHandler completionHandler);

@interface UAirshipPlugin() <UACordovaPluginManagerDelegate>
@property (nonatomic, copy) NSString *listenerCallbackID;
@property (nonatomic, weak) UAMessageViewController *messageViewController;
@property (nonatomic, strong) UACordovaPluginManager *pluginManager;
@property (nonatomic, weak) UAInAppMessageHTMLAdapter *htmlAdapter;
@property (nonatomic, assign) BOOL factoryBlockAssigned;
@end

@implementation UAirshipPlugin

- (void)pluginInitialize {
    UA_LINFO("Initializing UrbanAirship cordova plugin.");

    if (!self.pluginManager) {
        self.pluginManager = [UACordovaPluginManager pluginManagerWithDefaultConfig:self.commandDelegate.settings];
    }

    UA_LDEBUG(@"pluginIntialize called:plugin initializing and attempting takeOff with pluginManager:%@", self.pluginManager);
    [self.pluginManager attemptTakeOff];
}

- (void)dealloc {
    self.pluginManager.delegate = nil;
    self.listenerCallbackID = nil;
}

/**
 * Helper method to create a plugin result with the specified value.
 *
 * @param value The result's value.
 * @param status The result's status.
 * @returns A CDVPluginResult with specified value.
 */
- (CDVPluginResult *)pluginResultForValue:(id)value status:(CDVCommandStatus)status {
    /*
     NSString -> String
     NSNumber --> (Integer | Double)
     NSArray --> Array
     NSDictionary --> Object
     NSNull --> no return value
     nil -> no return value
     */

    // String
    if ([value isKindOfClass:[NSString class]]) {
        return [CDVPluginResult resultWithStatus:status
                                 messageAsString:[value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    }

    // Number
    if ([value isKindOfClass:[NSNumber class]]) {
        CFNumberType numberType = CFNumberGetType((CFNumberRef)value);
        //note: underlyingly, BOOL values are typedefed as char
        if (numberType == kCFNumberIntType || numberType == kCFNumberCharType) {
            return [CDVPluginResult resultWithStatus:status messageAsInt:[value intValue]];
        } else  {
            return [CDVPluginResult resultWithStatus:status messageAsDouble:[value doubleValue]];
        }
    }

    // Array
    if ([value isKindOfClass:[NSArray class]]) {
        return [CDVPluginResult resultWithStatus:status messageAsArray:value];
    }

    // Object
    if ([value isKindOfClass:[NSDictionary class]]) {
        return [CDVPluginResult resultWithStatus:status messageAsDictionary:value];
    }

    // Null
    if ([value isKindOfClass:[NSNull class]]) {
        return [CDVPluginResult resultWithStatus:status];
    }

    // Nil
    if (!value) {
        return [CDVPluginResult resultWithStatus:status];
    }

    UA_LERR(@"Cordova callback block returned unrecognized type: %@", NSStringFromClass([value class]));
    return [CDVPluginResult resultWithStatus:status];
}

/**
 * Helper method to perform a cordova command.
 *
 * @param command The cordova command.
 * @param block The UACordovaExecutionBlock to execute.
 */
- (void)performCallbackWithCommand:(CDVInvokedUrlCommand *)command withBlock:(UACordovaExecutionBlock)block {
    [self performCallbackWithCommand:command airshipRequired:YES withBlock:block];
}

/**
 * Helper method to perform a cordova command.
 *
 * @param command The cordova command.
 * @param block The UACordovaExecutionBlock to execute.
 */
- (void)performCallbackWithCommand:(CDVInvokedUrlCommand *)command
                   airshipRequired:(BOOL)airshipRequired
                         withBlock:(UACordovaExecutionBlock)block {

    if (airshipRequired && !self.pluginManager.isAirshipReady) {
        UA_LERR(@"Unable to run Urban Airship command. Takeoff not called.");
        id result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"TakeOff not called."];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    }

    UACordovaCompletionHandler completionHandler = ^(CDVCommandStatus status, id value) {
        CDVPluginResult *result = [self pluginResultForValue:value status:status];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    };

    if (!block) {
        completionHandler(CDVCommandStatus_OK, nil);
    } else {
        block(command.arguments, completionHandler);
    }
}

#pragma mark Cordova bridge

- (void)registerListener:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("registerListener called with command: %@ and callback ID:%@", command, command.callbackId);

    self.listenerCallbackID = command.callbackId;

    if (self.listenerCallbackID) {
        self.pluginManager.delegate = self;
    }
}

- (void)takeOff:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("takeOff called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command
                     airshipRequired:NO
                           withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
                               UA_LDEBUG(@"Performing takeOff with args: %@", args);

                               NSDictionary *config = [args objectAtIndex:0];
                               if (!config[@"production"] || !config[@"development"]) {
                                   completionHandler(CDVCommandStatus_ERROR, @"Invalid config");
                                   return;
                               }

                               if (self.pluginManager.isAirshipReady) {
                                   UA_LINFO(@"TakeOff already called. Config will be applied next app start.");
                               }

                               NSDictionary *development = config[@"development"];
                               [self.pluginManager setDevelopmentAppKey:development[@"appKey"] appSecret:development[@"appSecret"]];

                               NSDictionary *production = config[@"production"];
                               [self.pluginManager setProductionAppKey:production[@"appKey"] appSecret:production[@"appSecret"]];

                               if (!self.pluginManager.isAirshipReady) {
                                   [self.pluginManager attemptTakeOff];
                                   if (!self.pluginManager.isAirshipReady) {
                                       completionHandler(CDVCommandStatus_ERROR, @"Invalid config. Airship unable to takeOff.");
                                   }
                               }

                               completionHandler(CDVCommandStatus_OK, nil);
                           }];
}

- (void)setAutoLaunchDefaultMessageCenter:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("setAutoLaunchDefaultMessageCenter called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        BOOL enabled = [[args objectAtIndex:0] boolValue];
        self.pluginManager.autoLaunchMessageCenter = enabled;
        completionHandler(CDVCommandStatus_OK, nil);
    }];
}
- (void)setNotificationTypes:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("setNotificationTypes called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        UANotificationOptions types = [[args objectAtIndex:0] intValue];

        UA_LDEBUG(@"Setting notification types: %ld", (long)types);
        [UAirship push].notificationOptions = types;
        [[UAirship push] updateRegistration];

        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)setPresentationOptions:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("setPresentationOptions called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        UNNotificationPresentationOptions options = [[args objectAtIndex:0] intValue];

        UA_LDEBUG(@"Setting presentation options types: %ld", (long)options);
        [self.pluginManager setPresentationOptions:(NSUInteger)options];
        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)setUserNotificationsEnabled:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("setUserNotificationsEnabled called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        BOOL enabled = [[args objectAtIndex:0] boolValue];

        UA_LTRACE("setUserNotificationsEnabled set to:%@", enabled ? @"true" : @"false");

        [UAirship push].userPushNotificationsEnabled = enabled;

        //forces a reregistration
        [[UAirship push] updateRegistration];

        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)setAnalyticsEnabled:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("setAnalyticsEnabled called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        NSNumber *value = [args objectAtIndex:0];
        BOOL enabled = [value boolValue];
        [UAirship shared].analytics.enabled = enabled;

        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)setAssociatedIdentifier:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("setAssociatedIdentifier called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        NSString *key = [args objectAtIndex:0];
        NSString *identifier = [args objectAtIndex:1];

        UAAssociatedIdentifiers *identifiers = [[UAirship shared].analytics currentAssociatedDeviceIdentifiers];
        [identifiers setIdentifier:identifier forKey:key];
        [[UAirship shared].analytics associateDeviceIdentifiers:identifiers];

        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)isAnalyticsEnabled:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("isAnalyticsEnabled called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        BOOL enabled = [UAirship shared].analytics.enabled;

        completionHandler(CDVCommandStatus_OK, [NSNumber numberWithBool:enabled]);
    }];
}

- (void)isUserNotificationsEnabled:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("isUserNotificationsEnabled called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        BOOL enabled = [UAirship push].userPushNotificationsEnabled;
        completionHandler(CDVCommandStatus_OK, [NSNumber numberWithBool:enabled]);
    }];
}

- (void)isQuietTimeEnabled:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("isQuietTimeEnabled called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        BOOL enabled = [UAirship push].quietTimeEnabled;
        completionHandler(CDVCommandStatus_OK, [NSNumber numberWithBool:enabled]);
    }];
}

- (void)isInQuietTime:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("isInQuietTime called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        BOOL inQuietTime;
        NSDictionary *quietTimeDictionary = [UAirship push].quietTime;
        if (quietTimeDictionary) {
            NSString *start = [quietTimeDictionary valueForKey:@"start"];
            NSString *end = [quietTimeDictionary valueForKey:@"end"];

            NSDateFormatter *df = [NSDateFormatter new];
            df.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            df.dateFormat = @"HH:mm";

            NSDate *startDate = [df dateFromString:start];
            NSDate *endDate = [df dateFromString:end];

            NSDate *now = [NSDate date];

            inQuietTime = ([now earlierDate:startDate] == startDate && [now earlierDate:endDate] == now);
        } else {
            inQuietTime = NO;
        }

        completionHandler(CDVCommandStatus_OK, [NSNumber numberWithBool:inQuietTime]);
    }];
}

- (void)getLaunchNotification:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("getLaunchNotification called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        id event = self.pluginManager.lastReceivedNotificationResponse;

        if ([args firstObject]) {
            self.pluginManager.lastReceivedNotificationResponse = nil;
        }

        completionHandler(CDVCommandStatus_OK, event);
    }];
}

- (void)getDeepLink:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("getDeepLink called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        NSString *deepLink = self.pluginManager.lastReceivedDeepLink;

        if ([args firstObject]) {
            self.pluginManager.lastReceivedDeepLink = nil;
        }

        completionHandler(CDVCommandStatus_OK, deepLink);
    }];
}

- (void)getChannelID:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("getChannelID called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        completionHandler(CDVCommandStatus_OK, [UAirship push].channelID ?: @"");
    }];
}

- (void)getQuietTime:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("getQuietTime called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        NSDictionary *quietTimeDictionary = [UAirship push].quietTime;

        if (quietTimeDictionary) {

            NSString *start = [quietTimeDictionary objectForKey:@"start"];
            NSString *end = [quietTimeDictionary objectForKey:@"end"];

            NSDateFormatter *df = [NSDateFormatter new];
            df.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            df.dateFormat = @"HH:mm";

            NSDate *startDate = [df dateFromString:start];
            NSDate *endDate = [df dateFromString:end];

            // these will be nil if the dateformatter can't make sense of either string
            if (startDate && endDate) {
                NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
                NSDateComponents *startComponents = [gregorian components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:startDate];
                NSDateComponents *endComponents = [gregorian components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:endDate];

                completionHandler(CDVCommandStatus_OK, @{ @"startHour": @(startComponents.hour),
                                                          @"startMinute": @(startComponents.minute),
                                                          @"endHour": @(endComponents.hour),
                                                          @"endMinute": @(endComponents.minute) });

                return;
            }
        }

        completionHandler(CDVCommandStatus_OK, @{ @"startHour": @(0),
                                                  @"startMinute": @(0),
                                                  @"endHour": @(0),
                                                  @"endMinute": @(0) });
    }];
}

- (void)getTags:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("getTags called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        completionHandler(CDVCommandStatus_OK, [UAirship push].tags ?: [NSArray array]);
    }];
}

- (void)getBadgeNumber:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("getBadgeNumber called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        completionHandler(CDVCommandStatus_OK, @([UIApplication sharedApplication].applicationIconBadgeNumber));
    }];
}

- (void)getNamedUser:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("getNamedUser called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        completionHandler(CDVCommandStatus_OK, [UAirship namedUser].identifier ?: @"");
    }];
}

- (void)setTags:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("setTags called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        NSMutableArray *tags = [NSMutableArray arrayWithArray:[args objectAtIndex:0]];
        [UAirship push].tags = tags;
        [[UAirship push] updateRegistration];
        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)setQuietTimeEnabled:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("setQuietTimeEnabled called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        NSNumber *value = [args objectAtIndex:0];
        BOOL enabled = [value boolValue];
        [UAirship push].quietTimeEnabled = enabled;
        [[UAirship push] updateRegistration];

        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)setQuietTime:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("setQuietTime called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        id startHr = [args objectAtIndex:0];
        id startMin = [args objectAtIndex:1];
        id endHr = [args objectAtIndex:2];
        id endMin = [args objectAtIndex:3];

        [[UAirship push] setQuietTimeStartHour:[startHr integerValue] startMinute:[startMin integerValue] endHour:[endHr integerValue] endMinute:[endMin integerValue]];
        [[UAirship push] updateRegistration];

        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)setAutobadgeEnabled:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("setAutobadgeEnabled called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        NSNumber *number = [args objectAtIndex:0];
        BOOL enabled = [number boolValue];
        [UAirship push].autobadgeEnabled = enabled;

        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)setBadgeNumber:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("setBadgeNumber called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        id number = [args objectAtIndex:0];
        NSInteger badgeNumber = [number intValue];
        [[UAirship push] setBadgeNumber:badgeNumber];

        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)setNamedUser:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("setNamedUser called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        NSString *namedUserID = [args objectAtIndex:0];
        namedUserID = [namedUserID stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        [UAirship namedUser].identifier = [namedUserID length] ? namedUserID : nil;

        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)editNamedUserTagGroups:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("editNamedUserTagGroups called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {

        UANamedUser *namedUser = [UAirship namedUser];
        for (NSDictionary *operation in [args objectAtIndex:0]) {
            NSString *group = operation[@"group"];
            if ([operation[@"operation"] isEqualToString:@"add"]) {
                [namedUser addTags:operation[@"tags"] group:group];
            } else if ([operation[@"operation"] isEqualToString:@"remove"]) {
                [namedUser removeTags:operation[@"tags"] group:group];
            }
        }

        [namedUser updateTags];

        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)editChannelTagGroups:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("editChannelTagGroups called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {

        for (NSDictionary *operation in [args objectAtIndex:0]) {
            NSString *group = operation[@"group"];
            if ([operation[@"operation"] isEqualToString:@"add"]) {
                [[UAirship push] addTags:operation[@"tags"] group:group];
            } else if ([operation[@"operation"] isEqualToString:@"remove"]) {
                [[UAirship push] removeTags:operation[@"tags"] group:group];
            }
        }

        [[UAirship push] updateRegistration];

        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)resetBadge:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("resetBadge called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        [[UAirship push] resetBadge];
        [[UAirship push] updateRegistration];

        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)runAction:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("runAction called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        NSString *actionName = [args firstObject];
        id actionValue = args.count >= 2 ? [args objectAtIndex:1] : nil;

        [UAActionRunner runActionWithName:actionName
                                    value:actionValue
                                situation:UASituationManualInvocation
                        completionHandler:^(UAActionResult *actionResult) {

                            if (actionResult.status == UAActionStatusCompleted) {

                                /*
                                 * We are wrapping the value in an object to be consistent
                                 * with the Android implementation.
                                 */

                                NSMutableDictionary *result = [NSMutableDictionary dictionary];
                                [result setValue:actionResult.value forKey:@"value"];
                                completionHandler(CDVCommandStatus_OK, result);
                            } else {
                                NSString *error = [self errorMessageForAction:actionName result:actionResult];
                                completionHandler(CDVCommandStatus_ERROR, error);
                            }
                        }];

    }];
}

- (void)isAppNotificationsEnabled:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("isAppNotificationsEnabled called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        BOOL optedIn = [UAirship push].authorizedNotificationSettings != 0;
        completionHandler(CDVCommandStatus_OK, [NSNumber numberWithBool:optedIn]);
    }];
}

/**
 * Helper method to create an error message from an action result.
 *
 * @param actionName The name of the action.
 * @param actionResult The action result.
 * @return An error message, or nil if no error was found.
 */
- (NSString *)errorMessageForAction:(NSString *)actionName result:(UAActionResult *)actionResult {
    switch (actionResult.status) {
        case UAActionStatusActionNotFound:
            return [NSString stringWithFormat:@"Action %@ not found.", actionName];
        case UAActionStatusArgumentsRejected:
            return [NSString stringWithFormat:@"Action %@ rejected its arguments.", actionName];
        case UAActionStatusError:
            if (actionResult.error.localizedDescription) {
                return actionResult.error.localizedDescription;
            }
        case UAActionStatusCompleted:
            return nil;
    }

    return [NSString stringWithFormat:@"Action %@ failed with unspecified error", actionName];
}


- (void)displayMessageCenter:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("displayMessageCenter called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        [[UAirship messageCenter] display];
        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)setTitle:(CDVInvokedUrlCommand *)command {

}

- (void)getInboxMessages:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("getInboxMessages called with command arguments: %@", command.arguments);
    UA_LDEBUG(@"Getting messages");

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        NSMutableArray *messages = [NSMutableArray array];

        for (UAInboxMessage *message in [UAirship inbox].messageList.messages) {

            NSDictionary *icons = [message.rawMessageObject objectForKey:@"icons"];
            NSString *iconUrl = [icons objectForKey:@"list_icon"];
            NSNumber *sentDate = @([message.messageSent timeIntervalSince1970] * 1000);

            NSMutableDictionary *messageInfo = [NSMutableDictionary dictionary];
            [messageInfo setValue:message.title forKey:@"title"];
            [messageInfo setValue:message.messageID forKey:@"id"];
            [messageInfo setValue:sentDate forKey:@"sentDate"];
            [messageInfo setValue:iconUrl forKey:@"listIconUrl"];
            [messageInfo setValue:message.unread ? @NO : @YES  forKey:@"isRead"];
            [messageInfo setValue:message.extra forKey:@"extras"];

            [messages addObject:messageInfo];
        }

        completionHandler(CDVCommandStatus_OK, messages);
    }];
}

- (void)markInboxMessageRead:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("markInboxMessageRead called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        NSString *messageID = [command.arguments firstObject];
        UAInboxMessage *message = [[UAirship inbox].messageList messageForID:messageID];

        if (!message) {
            NSString *error = [NSString stringWithFormat:@"Message not found: %@", messageID];
            completionHandler(CDVCommandStatus_ERROR, error);
            return;
        }

        [[UAirship inbox].messageList markMessagesRead:@[message] completionHandler:nil];
        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)deleteInboxMessage:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("deleteInboxMessage called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        NSString *messageID = [command.arguments firstObject];
        UAInboxMessage *message = [[UAirship inbox].messageList messageForID:messageID];

        if (!message) {
            NSString *error = [NSString stringWithFormat:@"Message not found: %@", messageID];
            completionHandler(CDVCommandStatus_ERROR, error);
            return;
        }

        [[UAirship inbox].messageList markMessagesDeleted:@[message] completionHandler:nil];
        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)displayInboxMessage:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("displayInboxMessage called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        NSString *messageID = [command.arguments firstObject];
        UAInboxMessage *message = [[UAirship inbox].messageList messageForID:messageID];

        if (!message) {
            NSString *error = [NSString stringWithFormat:@"Message not found: %@", messageID];
            completionHandler(CDVCommandStatus_ERROR, error);
            return;
        }

        [self.messageViewController dismissViewControllerAnimated:YES completion:nil];

        UAMessageViewController *mvc = [[UAMessageViewController alloc] initWithNibName:@"UAMessageCenterMessageViewController"
                                                                                 bundle:[UAirship resources]];

        UINavigationController *navController =  [[UINavigationController alloc] initWithRootViewController:mvc];

        // Store a weak reference to the MessageViewController so we can dismiss it later
        self.messageViewController = mvc;

        [mvc loadMessageForID:message.messageID onlyIfChanged:YES onError:^{
            NSString *error = [NSString stringWithFormat:@"Message load resulted in errorMessage not found for message ID: %@", message.messageID];
            completionHandler(CDVCommandStatus_ERROR, error);
        }];

        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:navController animated:YES completion:nil];

        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)dismissInboxMessage:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("dismissInboxMessage called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        [self.messageViewController dismissViewControllerAnimated:YES completion:nil];
        self.messageViewController = nil;
        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)dismissOverlayInboxMessage:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("dismissOverlayInboxMessage called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        [self closeOverlayMessage];
        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)overlayInboxMessage:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("overlayInboxMessage called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        NSString *messageID = [command.arguments firstObject];
        UAInboxMessage *message = [[UAirship inbox].messageList messageForID:messageID];

        if (!message) {
            NSString *error = [NSString stringWithFormat:@"Message not found: %@", messageID];
            completionHandler(CDVCommandStatus_ERROR, error);
            return;
        }

        [self overlayInboxMessage:message];

        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (void)refreshInbox:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("refreshInbox called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        [[UAirship inbox].messageList retrieveMessageListWithSuccessBlock:^{
            completionHandler(CDVCommandStatus_OK, nil);
        } withFailureBlock:^{
            completionHandler(CDVCommandStatus_ERROR, @"Inbox failed to refresh");
        }];
    }];
}

- (void)getActiveNotifications:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("getActiveNotifications called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        if (@available(iOS 10.0, *)) {
            [[UNUserNotificationCenter currentNotificationCenter] getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> * _Nonnull notifications) {

                NSMutableArray *result = [NSMutableArray array];
                for(UNNotification *unnotification in notifications) {
                    UANotificationContent *content = [UANotificationContent notificationWithUNNotification:unnotification];
                    [result addObject:[self.pluginManager pushEventFromNotification:content]];
                }

                completionHandler(CDVCommandStatus_OK, result);
            }];
        } else {
            completionHandler(CDVCommandStatus_ERROR, @"Only available on iOS 10+");
        }
    }];
}

- (void)clearNotification:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("clearNotification called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        if (@available(iOS 10.0, *)) {
            NSString *identifier = command.arguments.firstObject;

            if (identifier) {
                [[UNUserNotificationCenter currentNotificationCenter] removeDeliveredNotificationsWithIdentifiers:@[identifier]];
            }

            completionHandler(CDVCommandStatus_OK, nil);
        }
    }];
}

- (void)clearNotifications:(CDVInvokedUrlCommand *)command {
    UA_LTRACE("clearNotifications called with command arguments: %@", command.arguments);

    [self performCallbackWithCommand:command withBlock:^(NSArray *args, UACordovaCompletionHandler completionHandler) {
        if (@available(iOS 10.0, *)) {
            [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
        }

        completionHandler(CDVCommandStatus_OK, nil);
    }];
}

- (BOOL)notifyListener:(NSString *)eventType data:(NSDictionary *)data {
    UA_LTRACE(@"notifyListener called with event type:%@ and data:%@", eventType, data);

    if (!self.listenerCallbackID) {
        UA_LTRACE(@"Listener callback unavailable, event %@", eventType);
        return false;
    }

    NSMutableDictionary *message = [NSMutableDictionary dictionary];
    [message setValue:eventType forKey:@"eventType"];
    [message setValue:data forKey:@"eventData"];

    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    [result setKeepCallbackAsBool:YES];

    [self.commandDelegate sendPluginResult:result callbackId:self.listenerCallbackID];

    return true;
}

- (void)displayOverlayMessage:(UAInboxMessage *)message {
    UA_LTRACE(@"Displaying overlay message:%@", message);

    if (!self.factoryBlockAssigned) {
        [[UAirship inAppMessageManager] setFactoryBlock:^id<UAInAppMessageAdapterProtocol> _Nonnull(UAInAppMessage * _Nonnull message) {
            UAInAppMessageHTMLAdapter *adapter = [UAInAppMessageHTMLAdapter adapterForMessage:message];
            UAInAppMessageHTMLDisplayContent *displayContent = (UAInAppMessageHTMLDisplayContent *) message.displayContent;
            NSURL *url = [NSURL URLWithString:displayContent.url];

            if ([url.scheme isEqualToString:@"message"]) {
                self.htmlAdapter = adapter;
            }

            return adapter;
        } forDisplayType:UAInAppMessageDisplayTypeHTML];

        self.factoryBlockAssigned = YES;
    }

    [UAActionRunner runActionWithName:kUAOverlayInboxMessageActionDefaultRegistryName
                                value:message.messageID
                            situation:UASituationManualInvocation];
}

- (void)closeOverlayMessage {
    UA_LTRACE(@"closeOverlayMessage called");

    UIViewController *vc = [self.htmlAdapter valueForKey:@"htmlViewController"];
# pragma clang diagnostic push
# pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [vc performSelector:NSSelectorFromString(@"dismissWithoutResolution")];
# pragma clang diagnostic pop
}

@end

