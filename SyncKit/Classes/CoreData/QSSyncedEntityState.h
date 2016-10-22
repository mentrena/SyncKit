//
//  QSSyncedEntityState.h
//  Pods
//
//  Created by Manuel Entrena on 10/07/2016.
//
//

#ifndef QSSyncedEntityState_h
#define QSSyncedEntityState_h

typedef NS_ENUM(NSInteger, QSSyncedEntityState) {
    QSSyncedEntityStateNew = 0,
    QSSyncedEntityStateChanged,
    QSSyncedEntityStateDeleted,
    QSSyncedEntityStateSynced,
    QSSyncedEntityStateInserted
};

#endif /* QSSyncedEntityState_h */
