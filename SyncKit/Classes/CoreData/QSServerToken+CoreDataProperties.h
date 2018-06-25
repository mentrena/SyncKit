//
//  QSServerToken+CoreDataProperties.h
//  
//
//  Created by Manuel Entrena on 24/03/2018.
//
//

#import "QSServerToken+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface QSServerToken (CoreDataProperties)

+ (NSFetchRequest<QSServerToken *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *token;

@end

NS_ASSUME_NONNULL_END
