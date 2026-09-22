
#import <Foundation/Foundation.h>

@implementation NSDictionary (GHSubscriptingCompat)

- (id)objectForKeyedSubscript:(id)key {
    return [self objectForKey:key];
}

@end

@implementation NSMutableDictionary (GHSubscriptingCompat)

- (void)setObject:(id)object forKeyedSubscript:(id<NSCopying>)key {
    if (object == nil) {
        [self removeObjectForKey:key];
    } else {
        [self setObject:object forKey:key];
    }
}

@end

@implementation NSArray (GHSubscriptingCompat)

- (id)objectAtIndexedSubscript:(NSUInteger)idx {
    return [self objectAtIndex:idx];
}

@end

@implementation NSMutableArray (GHSubscriptingCompat)

- (void)setObject:(id)object atIndexedSubscript:(NSUInteger)idx {
    [self replaceObjectAtIndex:idx withObject:object];
}

@end
