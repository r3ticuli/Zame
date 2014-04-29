//
//  PeopleNearbyViewController.m
//  Zame
//
//  Created by Leonard Loo on 20/4/14.
//  Copyright (c) 2014 CIS195. All rights reserved.
//

#import "PeopleNearbyViewController.h"
#import "NearbyUserViewController.h"
#import "MBProgressHUD.h"
// Useful macros
#define UIColorFromRGB(rgbValue) [UIColor \
colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
green:((float)((rgbValue & 0xFF00) >> 8))/255.0 \
blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

@interface PeopleNearbyViewController () <UIAlertViewDelegate, CLLocationManagerDelegate> {
    NSMutableArray *peopleWithinTwoKm;
    NSMutableArray *peopleWithinTwentyKm;
    NSMutableArray *peopleOnThisEarth;
    PFObject *myUser;
}

@property (nonatomic, strong) CLLocationManager *locationManager;

- (double) calculateDistanceFromLat1:(double)lat1
                             AndLon1:(double)lon1
                             AndLat2:(double)lat2
                             AndLon2:(double)lon2;

@end

@implementation PeopleNearbyViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    myUser = [PFUser currentUser];
    peopleWithinTwoKm = [[NSMutableArray alloc] init];
    peopleWithinTwentyKm = [[NSMutableArray alloc] init];
    peopleOnThisEarth = [[NSMutableArray alloc] init];
    [self getPeopleByIncreasingDistance];
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    // Pull to Refresh
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:refreshControl];
    
    // Update user's data through async blocks
    [self names:[[NSMutableArray alloc] init] andRequestURL:@"/me/movies?limit=100" of:@"movies"];
    [self names:[[NSMutableArray alloc] init] andRequestURL:@"/me/music?limit=100" of:@"music"];
    [self names:[[NSMutableArray alloc] init] andRequestURL:@"/me/books?limit=100" of:@"books"];
    [self names:[[NSMutableArray alloc] init] andRequestURL:@"/me/television?limit=100" of:@"television"];
    [self names:[[NSMutableArray alloc] init] andRequestURL:@"/me/sports?limit=100" of:@"sports"];
    [self names:[[NSMutableArray alloc] init] andRequestURL:@"/me/likes?limit=100" of:@"likes"];
    
    // Update user's distance
    [self.locationManager startUpdatingLocation];
    if (self.isGeolocationAvailable == NO) {
        NSLog(@"Not available");
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Please enable location services" message:@"You previously denied permission for location services. Please enable it in Settings again." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    } else {
        NSLog(@"Available");
    }
    
    
}

- (NSMutableArray *)      names: (NSMutableArray *) array
                  andRequestURL: (NSString *) url
                             of: (NSString *) type{
    
    FBRequest *request = [FBRequest requestForGraphPath:url];
    [request startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        NSDictionary *userData = (NSDictionary *)result;
        
        NSArray *dataArray = [userData objectForKey:@"data"];
        
        // Add names to array
        for(id key in dataArray) {
            [array addObject:[key objectForKey:@"name"]];
        }
        
        // Check if more data awaits
        id paging = [userData objectForKey:@"paging"];
        if ([paging objectForKey:@"next"]) {
            NSString* nextURL = [url stringByAppendingString:@"&offset=100"];
            [self names:array andRequestURL:nextURL of:type];
        }
        
    } ];
    
    [myUser setObject:array forKey:type.capitalizedString];
    [myUser saveInBackground];
    
    return array;
}


- (void)refresh:(UIRefreshControl *)refreshControl {
    [self getPeopleByIncreasingDistance];
    [refreshControl endRefreshing];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Update current user's location
#pragma mark - Location Manager

- (CLLocationManager *)locationManager
{
    if (!_locationManager) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        _locationManager.delegate = self;
    }
    
    return _locationManager;
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray *)locations
{
    CLGeocoder *reverseGeocoder = [[CLGeocoder alloc] init];
    
    CLLocation *locationToGeocode = [locations objectAtIndex:0];
    
    [reverseGeocoder reverseGeocodeLocation:locationToGeocode
                          completionHandler:^(NSArray *placemarks, NSError *error){
                              if (!error) {
                                  // Update lat, lon on Parse
                                  NSString *lat = [NSString stringWithFormat:@"%.9f", locationToGeocode.coordinate.latitude];
                                  NSString *lon = [NSString stringWithFormat:@"%.9f", locationToGeocode.coordinate.longitude];
                                  NSDictionary *dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:lat, @"lat", lon, @"lon", nil];
                                  [myUser setObject:dictionary forKey:@"Location"];
                                  [myUser saveInBackground];
                              }
                          }];
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error
{
    NSLog(@"%@", error);
}

- (BOOL)isGeolocationAvailable
{
    if(([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied)||(![CLLocationManager locationServicesEnabled])){
        return NO;
    }
    return YES;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    // Within 2km, Within 20km, On Earth
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    switch (section) {
        case 0 :
            return [peopleWithinTwoKm count];;
            break;
        case 1:
            return [peopleWithinTwentyKm count];
            break;
        case 2:
            return [peopleOnThisEarth count];
            break;
        default:
            return 0;
            break;
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{

    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"PeopleCell"];
    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    // This is for custom selection style color
    UIView *bgColorView = [[UIView alloc] init];
    bgColorView.backgroundColor = [UIColor colorWithRed:(76.0/255.0) green:(161.0/255.0) blue:(255.0/255.0) alpha:1.0];
    bgColorView.layer.masksToBounds = YES;
    cell.selectedBackgroundView = bgColorView;
    
    NSDictionary *person = [[NSDictionary alloc] init];
    switch (indexPath.section) {
        case 0 :
            person = [peopleWithinTwoKm objectAtIndex:indexPath.row];
            break;
        case 1:
            person = [peopleWithinTwentyKm objectAtIndex:indexPath.row];
            break;
        case 2:
            person = [peopleOnThisEarth objectAtIndex:indexPath.row];
            break;
        default:
            break;
    }

    
    NSMutableString *personName = [[person objectForKey:@"Name"] mutableCopy];
    cell.textLabel.text = personName;
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.textLabel.numberOfLines = 1;
    NSNumber *score = [person objectForKey:@"Score"];
    NSMutableString *scoreString = [[NSMutableString alloc] initWithString:@"ZScore: "];
    [scoreString appendString:[score stringValue]];
    cell.detailTextLabel.text = scoreString;

    return cell;
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0 :
            return @"Within 2km";
            break;
        case 1:
            return @"Within 20km";
            break;
        case 2:
            return @"On this planet";
            break;
        default:
            return @"";
            break;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //if user selects row, go to another view
    [self performSegueWithIdentifier: @"viewDetails" sender: self];
}



 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
 {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
     
     if ([[segue identifier] isEqualToString:@"viewDetails"]) {
         NSIndexPath *indexPath = [self.tableView
                                   indexPathForSelectedRow];
         
         //get the person
         NSDictionary *person = [[NSDictionary alloc] init];
         switch (indexPath.section) {
             case 0 :
                 person = [peopleWithinTwoKm objectAtIndex:indexPath.row];
                 break;
             case 1:
                 person = [peopleWithinTwentyKm objectAtIndex:indexPath.row];
                 break;
             case 2:
                 person = [peopleOnThisEarth objectAtIndex:indexPath.row];
                 break;
             default:
                 break;
         }
         
         //Send them
         NearbyUserViewController *vc = (NearbyUserViewController *)segue.destinationViewController;
         vc.nearbyUser = person;
         
     }
 }

#pragma mark - Distance, and Similarity Attributes

// Helper method that calculates distance from 2 pairs of lat,lon
- (double) calculateDistanceFromLat1:(double)lat1
                             AndLon1:(double)lon1
                             AndLat2:(double)lat2
                             AndLon2:(double)lon2
{
    CLLocation *locA = [[CLLocation alloc] initWithLatitude:lat1 longitude:lon1];
    CLLocation *locB = [[CLLocation alloc] initWithLatitude:lat2 longitude:lon2];
    CLLocationDistance distance = [locA distanceFromLocation:locB];
    return distance;
}

// Helper method to efficiently get similar items in two arrays
- (NSArray *) similarItemsIn: (NSArray *) arrayOne
                         and: (NSArray *) arrayTwo {
    NSMutableSet *setOne = [NSMutableSet setWithArray:arrayOne];
    NSSet *setTwo = [NSSet setWithArray:arrayTwo];
    [setOne intersectSet:setTwo];
    return [setOne allObjects];
}

// Create background task that pulls all entries in backend and calculate distance between them one by one
- (void) getPeopleByIncreasingDistance
{
    // First get ownself
    NSNumber *minScore = [myUser objectForKey:@"MinimumScore"];
    if (minScore == NULL) {
        minScore = [NSNumber numberWithInteger:0];
    }
    NSDictionary *myLocation = [myUser objectForKey:@"Location"];
    NSArray *myLikes = [myUser objectForKey:@"Likes"];
    NSArray *myMovies = [myUser objectForKey:@"Movies"];
    NSArray *myMusic = [myUser objectForKey:@"Music"];
    NSArray *myBooks = [myUser objectForKey:@"Books"];
    NSArray *myTelevision = [myUser objectForKey:@"Television"];
    NSArray *mySports = [myUser objectForKey:@"Sports"];
    NSString *myId = [myUser objectForKey:@"Fbid"];
    NSString *myName = [myUser objectForKey:@"Name"];
    PFQuery *query = [PFUser query];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error)
             {
                 if (!error) {
                     
                     // Remove all objects and reload
                     [peopleWithinTwoKm removeAllObjects];
                     [peopleWithinTwentyKm removeAllObjects];
                     [peopleOnThisEarth removeAllObjects];
                     
                     // Get each of their lat and lon
                     for (NSDictionary *object in objects) {
                         NSString *yourId = [object objectForKey:@"Fbid"];
                         if (![myId isEqualToString:yourId]) {
                             
                             // Similarity filtering
                             // Likes
                             NSArray *likes = [object objectForKey:@"Likes"];
                             NSArray *similarLikes = [self similarItemsIn:likes and:myLikes];
                             /* REMOVED BECAUSE IT'S TOO LAGGY
                             // Mutual Friends
                             NSString *pathSegment1 = @"/";
                             NSString *pathSegment2 = @"/mutualfriends/";
                             NSString *path = [[[pathSegment1 stringByAppendingString:myId] stringByAppendingString:pathSegment2] stringByAppendingString:yourId];
                             [FBRequestConnection startWithGraphPath:path
                                                          parameters:nil
                                                          HTTPMethod:@"GET"
                                                   completionHandler:^(
                                                                       FBRequestConnection *connection,
                                                                       id result,
                                                                       NSError *error
                                                                       ) {
                                                       mutualFriends = (NSArray *) result;
                                                   }];
                              */
                             // Movies
                             NSArray *movies = [object objectForKey:@"Movies"];
                             NSArray *similarMovies = [self similarItemsIn:movies and:myMovies];
                             // Music
                             NSArray *music = [object objectForKey:@"Music"];
                             NSArray *similarMusic = [self similarItemsIn:music and:myMusic];
                             // Books
                             NSArray *books = [object objectForKey:@"Books"];
                             NSArray *similarBooks = [self similarItemsIn:books and:myBooks];
                             // Television
                             NSArray *television = [object objectForKey:@"Television"];
                             NSArray *similarTelevision = [self similarItemsIn:television and:myTelevision];
                             // Sports
                             NSArray *sports = [object objectForKey:@"Sports"];
                             NSArray *similarSports = [self similarItemsIn:sports and:mySports];
                             // Score
                             NSNumber *score = [[NSNumber alloc] initWithInteger:[similarLikes count] + [similarMovies count] + [similarMusic count] + [similarBooks count] + [similarTelevision count] + [similarSports count] ];
                             // Only proceed when score >= minScore
                             if ([score integerValue] >= [minScore integerValue]) {
                                 // Location filtering
                                 NSDictionary *location = [object objectForKey:@"Location"];
                                 NSString *name = [object objectForKey:@"Name"];
                                 // Grab first name
                                 NSArray *firstLastStrings = [name componentsSeparatedByString:@" "];
                                 NSString *firstName = [firstLastStrings objectAtIndex:0];
                                 // Grab Email
                                 NSString *email = [object objectForKey:@"Email"];
                                 // Calculate distance
                                 double distance = [self calculateDistanceFromLat1: [[myLocation objectForKey:@"lat"] doubleValue] AndLon1:[[myLocation objectForKey:@"lon"] doubleValue] AndLat2:[[location objectForKey:@"lat"] doubleValue] AndLon2:[[location objectForKey:@"lon"] doubleValue]];
                                 // Build list
                                 NSNumber *distanceNum = [NSNumber numberWithDouble:distance];
                                 NSDictionary *similarity = [[NSDictionary alloc] initWithObjectsAndKeys:similarLikes, @"Likes", similarMovies, @"Movies", similarMusic, @"Music", similarBooks, @"Books", similarTelevision, @"Television", similarSports, @"Sports", nil];
                                 NSDictionary *personEntry = [[NSDictionary alloc] initWithObjectsAndKeys:myName, @"MyName",firstName, @"Name", distanceNum, @"Distance", yourId, @"Fbid", similarity, @"Similarity", score, @"Score", email, @"Email", nil];
                                 
                                 if (distance < 2000) {
                                     [peopleWithinTwoKm addObject:personEntry];
                                 } else if (distance < 20000) {
                                     [peopleWithinTwentyKm addObject:personEntry];
                                 } else {
                                     [peopleOnThisEarth addObject:personEntry];
                                 }
                             }
                         }
                     }
                 } else {
                     NSLog(@"From getPeopleByIncreasingDistance: %@", error);
                 }
                 // Sort all three arrays
                 NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"Distance"
                                                                                ascending:YES];
                 NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
                 peopleWithinTwoKm = [[[peopleWithinTwoKm mutableCopy] sortedArrayUsingDescriptors:sortDescriptors] mutableCopy];
                 peopleWithinTwentyKm = [[[peopleWithinTwentyKm mutableCopy]sortedArrayUsingDescriptors:sortDescriptors] mutableCopy];
                 peopleOnThisEarth = [[[peopleOnThisEarth mutableCopy] sortedArrayUsingDescriptors:sortDescriptors] mutableCopy];
                 [self.tableView reloadData];
                 if ([peopleWithinTwoKm count] == 0 && [peopleWithinTwentyKm count] == 0 && [peopleOnThisEarth count] == 0) {
                     UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Oops! You're that unique." message:@"Unfortunately, you're a really special individual. No one around you has zame interests. If you're willing to settle for less zame people, go to Settings and lower the minimum ZScore." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                     [alert show];
                 }
                 [MBProgressHUD hideHUDForView:self.view animated:YES];
             }];
        });
    
    });
    
    
}






@end
