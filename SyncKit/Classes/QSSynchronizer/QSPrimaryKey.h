//
//  QSPrimaryKey.h
//  Pods
//
//  Created by Manuel Entrena on 28/12/2016.
//
//

#import <Foundation/Foundation.h>

/**
*   The name of the property that acts as primary key for objects of this class. Primary key values are expected to remain the same
 *  for the lifetime of the object, and they are expected to be unique.
*/
@protocol QSPrimaryKey <NSObject>

+ (nonnull NSString *)primaryKey;

@end

/**
 *  The name of the property that references this object's parent, if there's one. Used to create a hierarchy
 *  of objects for CloudKit sharing.
 */
@protocol QSParentKey <NSObject>

+ (nonnull NSString *)parentKey;

@end
