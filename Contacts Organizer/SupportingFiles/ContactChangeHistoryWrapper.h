//
//  ContactChangeHistoryWrapper.h
//  Contacts Organizer
//
//  Minimal Objective-C shim to surface CNContactStore's change-history
//  enumerator API to Swift.
//

#import <Foundation/Foundation.h>
#import <Contacts/Contacts.h>

NS_ASSUME_NONNULL_BEGIN

@interface ContactChangeHistoryWrapper : NSObject

- (instancetype)initWithStore:(CNContactStore *)store;

- (NSArray<CNChangeHistoryEvent *> * _Nullable)
    fetchChangeHistoryWithRequest:(CNChangeHistoryFetchRequest *)request
              currentHistoryToken:(NSData * _Nullable * _Nullable)currentTokenOut
                            error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
