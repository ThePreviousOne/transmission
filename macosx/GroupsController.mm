// This file Copyright © 2007-2022 Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "GroupsController.h"
#import "NSMutableArrayAdditions.h"
#import "NSApplicationAdditions.h"

#define ICON_WIDTH 16.0
#define BORDER_WIDTH 1.25
#define ICON_WIDTH_SMALL 12.0

@interface GroupsController ()

@property(nonatomic, readonly) NSMutableArray<NSMutableDictionary*>* fGroups;

- (void)saveGroups;

- (NSImage*)imageForGroup:(NSMutableDictionary*)dict;

- (BOOL)torrent:(Torrent*)torrent doesMatchRulesForGroupAtIndex:(NSInteger)index;

@end

@implementation GroupsController

GroupsController* fGroupsInstance = nil;

+ (GroupsController*)groups
{
    if (!fGroupsInstance)
    {
        fGroupsInstance = [[GroupsController alloc] init];
    }
    return fGroupsInstance;
}

- (instancetype)init
{
    if ((self = [super init]))
    {
        NSData* data;
        if ((data = [NSUserDefaults.standardUserDefaults dataForKey:@"GroupDicts"]))
        {
            if (@available(macOS 10.13, *))
            {
                _fGroups = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObjects:NSMutableArray.class,
                                                                                              NSMutableDictionary.class,
                                                                                              NSNumber.class,
                                                                                              NSColor.class,
                                                                                              NSString.class,
                                                                                              NSPredicate.class,
                                                                                              nil]
                                                               fromData:data
                                                                  error:nil];
            }
            else
            {
                _fGroups = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            }
        }
        else if ((data = [NSUserDefaults.standardUserDefaults dataForKey:@"Groups"])) //handle old groups
        {
            _fGroups = [NSUnarchiver unarchiveObjectWithData:data];
            [NSUserDefaults.standardUserDefaults removeObjectForKey:@"Groups"];
            [self saveGroups];
        }
        if (_fGroups == nil)
        {
            //default groups
            NSMutableDictionary* red = [NSMutableDictionary
                dictionaryWithObjectsAndKeys:NSColor.systemRedColor, @"Color", NSLocalizedString(@"Red", "Groups -> Name"), @"Name", @0, @"Index", nil];

            NSMutableDictionary* orange = [NSMutableDictionary
                dictionaryWithObjectsAndKeys:NSColor.systemOrangeColor, @"Color", NSLocalizedString(@"Orange", "Groups -> Name"), @"Name", @1, @"Index", nil];

            NSMutableDictionary* yellow = [NSMutableDictionary
                dictionaryWithObjectsAndKeys:NSColor.systemYellowColor, @"Color", NSLocalizedString(@"Yellow", "Groups -> Name"), @"Name", @2, @"Index", nil];

            NSMutableDictionary* green = [NSMutableDictionary
                dictionaryWithObjectsAndKeys:NSColor.systemGreenColor, @"Color", NSLocalizedString(@"Green", "Groups -> Name"), @"Name", @3, @"Index", nil];

            NSMutableDictionary* blue = [NSMutableDictionary
                dictionaryWithObjectsAndKeys:NSColor.systemBlueColor, @"Color", NSLocalizedString(@"Blue", "Groups -> Name"), @"Name", @4, @"Index", nil];

            NSMutableDictionary* purple = [NSMutableDictionary
                dictionaryWithObjectsAndKeys:NSColor.systemPurpleColor, @"Color", NSLocalizedString(@"Purple", "Groups -> Name"), @"Name", @5, @"Index", nil];

            NSMutableDictionary* gray = [NSMutableDictionary
                dictionaryWithObjectsAndKeys:NSColor.systemGrayColor, @"Color", NSLocalizedString(@"Gray", "Groups -> Name"), @"Name", @6, @"Index", nil];

            _fGroups = [[NSMutableArray alloc] initWithObjects:red, orange, yellow, green, blue, purple, gray, nil];
            [self saveGroups]; //make sure this is saved right away
        }
    }

    return self;
}

- (NSInteger)numberOfGroups
{
    return self.fGroups.count;
}

- (NSInteger)rowValueForIndex:(NSInteger)index
{
    if (index != -1)
    {
        for (NSUInteger i = 0; i < self.fGroups.count; i++)
        {
            if (index == [self.fGroups[i][@"Index"] integerValue])
            {
                return i;
            }
        }
    }
    return -1;
}

- (NSInteger)indexForRow:(NSInteger)row
{
    return [self.fGroups[row][@"Index"] integerValue];
}

- (NSString*)nameForIndex:(NSInteger)index
{
    NSInteger orderIndex = [self rowValueForIndex:index];
    return orderIndex != -1 ? self.fGroups[orderIndex][@"Name"] : nil;
}

- (void)setName:(NSString*)name forIndex:(NSInteger)index
{
    NSInteger orderIndex = [self rowValueForIndex:index];
    self.fGroups[orderIndex][@"Name"] = name;
    [self saveGroups];

    [NSNotificationCenter.defaultCenter postNotificationName:@"UpdateGroups" object:self];
}

- (NSImage*)imageForIndex:(NSInteger)index
{
    NSInteger orderIndex = [self rowValueForIndex:index];
    return orderIndex != -1 ? [self imageForGroup:self.fGroups[orderIndex]] : [self imageForGroupNone];
}

- (NSColor*)colorForIndex:(NSInteger)index
{
    NSInteger orderIndex = [self rowValueForIndex:index];
    return orderIndex != -1 ? self.fGroups[orderIndex][@"Color"] : nil;
}

- (void)setColor:(NSColor*)color forIndex:(NSInteger)index
{
    NSMutableDictionary* dict = self.fGroups[[self rowValueForIndex:index]];
    [dict removeObjectForKey:@"Icon"];

    dict[@"Color"] = color;

    [GroupsController.groups saveGroups];
    [NSNotificationCenter.defaultCenter postNotificationName:@"UpdateGroups" object:self];
}

- (BOOL)usesCustomDownloadLocationForIndex:(NSInteger)index
{
    if (![self customDownloadLocationForIndex:index])
    {
        return NO;
    }

    NSInteger orderIndex = [self rowValueForIndex:index];
    return [self.fGroups[orderIndex][@"UsesCustomDownloadLocation"] boolValue];
}

- (void)setUsesCustomDownloadLocation:(BOOL)useCustomLocation forIndex:(NSInteger)index
{
    NSMutableDictionary* dict = self.fGroups[[self rowValueForIndex:index]];

    dict[@"UsesCustomDownloadLocation"] = @(useCustomLocation);

    [GroupsController.groups saveGroups];
}

- (NSString*)customDownloadLocationForIndex:(NSInteger)index
{
    NSInteger orderIndex = [self rowValueForIndex:index];
    return orderIndex != -1 ? self.fGroups[orderIndex][@"CustomDownloadLocation"] : nil;
}

- (void)setCustomDownloadLocation:(NSString*)location forIndex:(NSInteger)index
{
    NSMutableDictionary* dict = self.fGroups[[self rowValueForIndex:index]];
    dict[@"CustomDownloadLocation"] = location;

    [GroupsController.groups saveGroups];
}

- (BOOL)usesAutoAssignRulesForIndex:(NSInteger)index
{
    NSInteger orderIndex = [self rowValueForIndex:index];
    if (orderIndex == -1)
    {
        return NO;
    }

    NSNumber* assignRules = self.fGroups[orderIndex][@"UsesAutoGroupRules"];
    return assignRules && assignRules.boolValue;
}

- (void)setUsesAutoAssignRules:(BOOL)useAutoAssignRules forIndex:(NSInteger)index
{
    NSMutableDictionary* dict = self.fGroups[[self rowValueForIndex:index]];

    dict[@"UsesAutoGroupRules"] = @(useAutoAssignRules);

    [GroupsController.groups saveGroups];
}

- (NSPredicate*)autoAssignRulesForIndex:(NSInteger)index
{
    NSInteger orderIndex = [self rowValueForIndex:index];
    if (orderIndex == -1)
    {
        return nil;
    }

    return self.fGroups[orderIndex][@"AutoGroupRules"];
}

- (void)setAutoAssignRules:(NSPredicate*)predicate forIndex:(NSInteger)index
{
    NSMutableDictionary* dict = self.fGroups[[self rowValueForIndex:index]];

    if (predicate)
    {
        dict[@"AutoGroupRules"] = predicate;
        [GroupsController.groups saveGroups];
    }
    else
    {
        [dict removeObjectForKey:@"AutoGroupRules"];
        [self setUsesAutoAssignRules:NO forIndex:index];
    }
}

- (void)addNewGroup
{
    //find the lowest index
    NSMutableIndexSet* candidates = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.fGroups.count + 1)];
    for (NSDictionary* dict in self.fGroups)
    {
        [candidates removeIndex:[dict[@"Index"] integerValue]];
    }

    NSInteger const index = candidates.firstIndex;

    [self.fGroups addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:@(index),
                                                                              @"Index",
                                                                              [NSColor colorWithCalibratedRed:0.0 green:0.65
                                                                                                         blue:1.0
                                                                                                        alpha:1.0],
                                                                              @"Color",
                                                                              @"",
                                                                              @"Name",
                                                                              nil]];

    [NSNotificationCenter.defaultCenter postNotificationName:@"UpdateGroups" object:self];
    [self saveGroups];
}

- (void)removeGroupWithRowIndex:(NSInteger)row
{
    NSInteger index = [self.fGroups[row][@"Index"] integerValue];
    [self.fGroups removeObjectAtIndex:row];

    [NSNotificationCenter.defaultCenter postNotificationName:@"GroupValueRemoved" object:self
                                                    userInfo:@{ @"Index" : @(index) }];

    if (index == [NSUserDefaults.standardUserDefaults integerForKey:@"FilterGroup"])
    {
        [NSUserDefaults.standardUserDefaults setInteger:-2 forKey:@"FilterGroup"];
    }

    [NSNotificationCenter.defaultCenter postNotificationName:@"UpdateGroups" object:self];
    [self saveGroups];
}

- (void)moveGroupAtRow:(NSInteger)oldRow toRow:(NSInteger)newRow
{
    [self.fGroups moveObjectAtIndex:oldRow toIndex:newRow];

    [self saveGroups];
    [NSNotificationCenter.defaultCenter postNotificationName:@"UpdateGroups" object:self];
}

- (NSMenu*)groupMenuWithTarget:(id)target action:(SEL)action isSmall:(BOOL)small
{
    NSMenu* menu = [[NSMenu alloc] initWithTitle:@"Groups"];

    NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"None", "Groups -> Menu") action:action
                                           keyEquivalent:@""];
    item.target = target;
    item.tag = -1;

    NSImage* icon = [self imageForGroupNone];
    if (small)
    {
        icon = [icon copy];
        icon.size = NSMakeSize(ICON_WIDTH_SMALL, ICON_WIDTH_SMALL);

        item.image = icon;
    }
    else
    {
        item.image = icon;
    }

    [menu addItem:item];

    for (NSMutableDictionary* dict in self.fGroups)
    {
        item = [[NSMenuItem alloc] initWithTitle:dict[@"Name"] action:action keyEquivalent:@""];
        item.target = target;

        item.tag = [dict[@"Index"] integerValue];

        NSImage* icon = [self imageForGroup:dict];
        if (small)
        {
            icon = [icon copy];
            icon.size = NSMakeSize(ICON_WIDTH_SMALL, ICON_WIDTH_SMALL);

            item.image = icon;
        }
        else
        {
            item.image = icon;
        }

        [menu addItem:item];
    }

    return menu;
}

- (NSInteger)groupIndexForTorrent:(Torrent*)torrent
{
    for (NSDictionary* group in self.fGroups)
    {
        NSInteger row = [group[@"Index"] integerValue];
        if ([self torrent:torrent doesMatchRulesForGroupAtIndex:row])
        {
            return row;
        }
    }
    return -1;
}

#pragma mark - Private

- (void)saveGroups
{
    //don't archive the icon
    NSMutableArray* groups = [NSMutableArray arrayWithCapacity:self.fGroups.count];
    for (NSDictionary* dict in self.fGroups)
    {
        NSMutableDictionary* tempDict = [dict mutableCopy];
        [tempDict removeObjectForKey:@"Icon"];
        [groups addObject:tempDict];
    }

    [NSUserDefaults.standardUserDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:groups] forKey:@"GroupDicts"];
}

- (NSImage*)imageForGroupNone
{
    static NSImage* icon;
    if (icon)
    {
        return icon;
    }

    icon = [NSImage imageWithSize:NSMakeSize(ICON_WIDTH, ICON_WIDTH) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        //shape
        rect = NSInsetRect(rect, BORDER_WIDTH / 2, BORDER_WIDTH / 2);
        NSBezierPath* bp = [NSBezierPath bezierPathWithOvalInRect:rect];
        bp.lineWidth = BORDER_WIDTH;

        //border
        // code reference for dashed style
        //CGFloat dashAndGapLength = M_PI * rect.size.width / 8;
        //CGFloat pattern[2] = { dashAndGapLength * .5, dashAndGapLength * .5 };
        //[bp setLineDash:pattern count:2 phase:0];

        [NSColor.controlTextColor setStroke];
        [bp stroke];

        return YES;
    }];
    [icon setTemplate:YES];

    return icon;
}

- (NSImage*)imageForGroup:(NSMutableDictionary*)dict
{
    NSImage* icon;
    if ((icon = dict[@"Icon"]))
    {
        return icon;
    }

    NSColor* color = dict[@"Color"];

    icon = [NSImage imageWithSize:NSMakeSize(ICON_WIDTH, ICON_WIDTH) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        //shape
        rect = NSInsetRect(rect, BORDER_WIDTH / 2, BORDER_WIDTH / 2);
        NSBezierPath* bp = [NSBezierPath bezierPathWithOvalInRect:rect];
        bp.lineWidth = BORDER_WIDTH;

        //border
        CGFloat fractionOfBlendedColor = [NSApp isDarkMode] ? 0.15 : 0.3;
        NSColor* borderColor = [color blendedColorWithFraction:fractionOfBlendedColor ofColor:NSColor.controlTextColor];
        [borderColor setStroke];
        [bp stroke];

        //inside
        [color setFill];
        [bp fill];

        return YES;
    }];

    dict[@"Icon"] = icon;

    return icon;
}

- (BOOL)torrent:(Torrent*)torrent doesMatchRulesForGroupAtIndex:(NSInteger)index
{
    if (![self usesAutoAssignRulesForIndex:index])
    {
        return NO;
    }

    NSPredicate* predicate = [self autoAssignRulesForIndex:index];
    BOOL eval = NO;
    @try
    {
        eval = [predicate evaluateWithObject:torrent];
    }
    @catch (NSException* exception)
    {
        NSLog(@"Error when evaluating predicate (%@) - %@", predicate, exception);
    }
    @finally
    {
        return eval;
    }
}

@end
