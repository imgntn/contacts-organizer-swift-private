//
//  ContactChangeHistoryWrapper.m
//  Contacts Organizer
//

#import "ContactChangeHistoryWrapper.h"

@implementation ContactChangeHistoryWrapper {
    CNContactStore *_store;
}

- (instancetype)initWithStore:(CNContactStore *)store {
    self = [super init];
    if (self) {
        _store = store;
    }
    return self;
}

- (NSArray<CNChangeHistoryEvent *> *)
    fetchChangeHistoryWithRequest:(CNChangeHistoryFetchRequest *)request
              currentHistoryToken:(NSData * _Nullable * _Nullable)currentTokenOut
                            error:(NSError * _Nullable * _Nullable)error {
    CNFetchResult<NSEnumerator<CNChangeHistoryEvent *> *> *result =
        [_store enumeratorForChangeHistoryFetchRequest:request error:error];

    if (result == nil) {
        return nil;
    }

    if (currentTokenOut) {
        *currentTokenOut = result.currentHistoryToken;
    }

    NSEnumerator<CNChangeHistoryEvent *> *enumerator = result.value;
    NSMutableArray<CNChangeHistoryEvent *> *events = [NSMutableArray array];

    for (CNChangeHistoryEvent *event in enumerator) {
        [events addObject:event];
    }

    return events;
}

@end
