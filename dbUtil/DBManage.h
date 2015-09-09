//
//  DBManage.h
//  tapGuesture
//
//  Created by luolihacker on 15/8/5.
//  Copyright (c) 2015年 luolihacker. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import "AppnameModel.h"

@interface DBManage : NSObject

- (sqlite3 *)createDBOrOpen;
- (BOOL)createDBTable;
- (BOOL)excuteSql:(NSString *)sql andDB:(sqlite3 *)db;
- (BOOL)insert:(NSString *)sql;
- (NSMutableArray *)queryAllData;
- (void)deleteData:(NSString *)appID;


@end
