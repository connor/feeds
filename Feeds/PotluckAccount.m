//
//  PotluckAccount.m
//  Feeds
//
//  Created by Connor Montgomery on 8/20/13.
//  Copyright (c) 2013 Spotlight Mobile. All rights reserved.
//

#import "PotluckAccount.h"

@implementation PotluckAccount

+ (void)load { [Account registerClass:self]; }
+ (BOOL)requiresUsername { return YES; }
+ (BOOL)requiresPassword { return YES; }
+ (NSString *)friendlyAccountName { return @"Potluck"; }
+ (NSString *)shortAccountName { return @"Potluck"; }
+ (NSString *)usernameLabel { return @"Email Address:"; }
+ (NSTimeInterval)defaultRefreshInterval { return 5*60; }
- (NSString *)iconPrefix { return @"Potluck"; }

- (void)validateWithPassword:(NSString *)password {
    NSString *URL = [NSString stringWithFormat:@"https://www.potluck.it/sessions.json"];
 
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc]
                                    initWithURL:[NSURL URLWithString:URL]];
    [request setHTTPMethod:@"POST"];
    
    NSDictionary* postData = [NSDictionary dictionaryWithObjectsAndKeys:
                              self.username, @"user[email]",
                              password, @"user[password]",
                              nil];

    NSString *postDataString = [self serializeParams:postData];
    [request setHTTPBody: [postDataString dataUsingEncoding: NSUTF8StringEncoding]];
    self.request = [SMWebRequest requestWithURLRequest:request delegate:nil context:NULL];
    [self.request addTarget:self action:@selector(meRequestComplete:) forRequestEvents:SMWebRequestEventComplete];
    [self.request addTarget:self action:@selector(meRequestError:) forRequestEvents:SMWebRequestEventError];
    [self.request start];
}

-(NSString *)serializeParams:(NSDictionary *)params {
    /*
     
     Convert an NSDictionary to a query string
     
     */
    
    NSMutableArray* pairs = [NSMutableArray array];
    for (NSString* key in [params keyEnumerator]) {
        id value = [params objectForKey:key];
        if ([value isKindOfClass:[NSDictionary class]]) {
            for (NSString *subKey in value) {
                NSString* escaped_value = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                              (CFStringRef)[value objectForKey:subKey],
                                                                                              NULL,
                                                                                              (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                              kCFStringEncodingUTF8));
                [pairs addObject:[NSString stringWithFormat:@"%@[%@]=%@", key, subKey, escaped_value]];
            }
        } else if ([value isKindOfClass:[NSArray class]]) {
            for (NSString *subValue in value) {
                NSString* escaped_value = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                              (CFStringRef)subValue,
                                                                                              NULL,
                                                                                              (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                              kCFStringEncodingUTF8));
                [pairs addObject:[NSString stringWithFormat:@"%@[]=%@", key, escaped_value]];
            }
        } else {
            NSString* escaped_value = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                          (CFStringRef)[params objectForKey:key],
                                                                                          NULL,
                                                                                          (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                          kCFStringEncodingUTF8));
            [pairs addObject:[NSString stringWithFormat:@"%@=%@", key, escaped_value]];
        }
    }
    return [pairs componentsJoinedByString:@"&"];
}

- (void)meRequestComplete:(NSData *)data {
    
    NSDictionary *responseData = [data objectFromJSONData];
    
    NSString *authToken = [responseData objectForKey:@"auth_token"];
    NSString *mainFeedString = @"https://www.potluck.it/rooms.json";
    Feed *mainFeed = [Feed feedWithURLString:mainFeedString title:@"Latest Activity" account:self];
    mainFeed.requestHeaders = @{ @"X-Auth-Token": authToken };
    mainFeed.requestHeaders = @{ @"X-Application-Name": @"Feeds.app fork, by Connor Montgomery" };
    mainFeed.incremental = YES;

    self.feeds = @[mainFeed];
    
    [self.delegate account:self validationDidCompleteWithNewPassword:nil];
}

+ (NSArray *)itemsForRequest:(SMWebRequest *)request data:(NSData *)data domain:(NSString *)domain username:(NSString *)username password:(NSString *)password {
    
    NSMutableArray *items = [NSMutableArray array];
    NSLog(@"%@", items);
    
    NSArray *rooms = [data objectFromJSONData];
    
    for (NSDictionary *room in rooms) {
        NSString *date = room[@"created_at"];
//        NSString *userId = room[@"creator_id"];
        NSString *url = [NSString stringWithFormat:@"https://www.potluck.it/rooms/%@", room[@"identifier"]];
        NSString *title = room[@"topic"];
//        
//        NSURL *authorLookupURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.potluck.it/users/%@.json", userId]];
//        NSData *authorData = [self extraDataWithContentsOfURLRequest:[NSMutableURLRequest requestWithURL:authorLookupURL]];
//        NSDictionary *author = [[authorData objectFromJSONData] objectForKey:@"user"];
//        NSLog(@"%@", author);
        
        FeedItem *item = [FeedItem new];
        item.rawDate = date;
        item.published = AutoFormatDate(date);
        item.viewed = NO;
        item.updated = item.published;
        item.link = [NSURL URLWithString:url];
        item.title = title;
        item.notified = NO;
        item.authoredByMe = NO;

        [items addObject:item];
    }
    
    return items;
}

- (void)meRequestError:(NSError *)error {
    if (error.code == 404)
        [self.delegate account:self validationDidFailWithMessage:@"Could not log in to the given Basecamp account. Please check your domain, username, and password." field:0];
    else
        [self.delegate account:self validationDidFailWithMessage:error.localizedDescription field:AccountFailingFieldUnknown];
}

@end
