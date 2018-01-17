//
//  QSServerToken.h
//  Pods
//
//  Created by Manuel Entrena on 24/05/2018.
//

#import <Realm/Realm.h>

@interface QSServerToken : RLMObject

@property (nullable, nonatomic, strong) NSData *token;

@end
