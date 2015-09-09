//
//  DBManage.m
//  tapGuesture
//
//  Created by luolihacker on 15/8/5.
//  Copyright (c) 2015年 luolihacker. All rights reserved.
//

#import "DBManage.h"
#define DBNAME @"app.sqlite"


@implementation DBManage
-(sqlite3 *)createDBOrOpen
{
    //获取iPhone上sqlite3的数据库文件地址
    NSLog(@"createDBOrOpen!!!");
    sqlite3 *db;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documents = [paths objectAtIndex:0];
    NSString *database_path = [documents stringByAppendingPathComponent:DBNAME];
    NSLog(@"%@",database_path);
    if (sqlite3_open([database_path UTF8String], &db) != SQLITE_OK) {
        sqlite3_close(db);
        NSLog(@"打开数据库失败！");
    }
    return db;
}
-(BOOL)createDBTable
{
    NSLog(@"createDBTable!!!");
    sqlite3 *db = [self createDBOrOpen];
    BOOL ifSuccess = [self excuteSql:@"create table if not exists appinfo(id integer primary key autoincrement,apptitle nvarchar(64),appimage nvarchar(64));" andDB:db];
    return ifSuccess;
    
}
-(BOOL)excuteSql:(NSString *)sql andDB:(sqlite3 *)db
{
    NSLog(@"sql = %@",sql);
    char *err;
    if (sqlite3_exec(db, [sql UTF8String], NULL, NULL, &err) != SQLITE_OK) {
        sqlite3_close(db);
        NSLog(@"执行sql失败！");
        return NO;
    }
    NSLog(@"执行sql成功！！！！");
    return YES;
}
-(BOOL)insert:(NSString *)sql
{
    sqlite3 *db = [self createDBOrOpen];
    if (![self excuteSql:sql andDB:db]) {
        NSLog(@"插入数据失败！");
        return NO;
    }
    NSLog(@"插入数据成功");
    return YES;
}
-(NSMutableDictionary *)queryAllData
{
    sqlite3 *db = [self createDBOrOpen];
    sqlite3_stmt *stmt;
    NSMutableDictionary *resultdic = [NSMutableDictionary dictionary];
    NSString *sql = @"select * from appinfo;";
    AppnameModel *appNameModel = [[AppnameModel alloc]init];
    if (sqlite3_prepare_v2(db, [sql UTF8String], -1, &stmt, nil)==SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            appNameModel.appName = [[NSString alloc]initWithUTF8String:(char *)sqlite3_column_text(stmt, 1)];
            appNameModel.appImgPath = [[NSString alloc]initWithUTF8String:(char *)sqlite3_column_text(stmt, 2)];
            [resultdic setValue:appNameModel forKey:appNameModel.appName];
            
        }
    }
    else
    {
        return nil;
    }
    sqlite3_close(db);
    return resultdic;
}
-(void)deleteData:(NSString *)appID
{
    if (appID == nil) {
        NSString *deleteSql = [NSString stringWithFormat:@"delete from t_modals;"];
        [self excuteSql:deleteSql andDB:[self createDBOrOpen]];
    }else
    {
    NSString *deleteSql = [NSString stringWithFormat:@"delete  from t_modals where appID = %@;",appID];
    [self excuteSql:deleteSql andDB:[self createDBOrOpen]];
    }
}
@end
