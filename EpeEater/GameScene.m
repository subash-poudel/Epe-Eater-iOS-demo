//
//  GameScene.m
//  EpeEater
//  inspired from https://play.google.com/store/apps/details?id=shakescreen.EpeEaterLite&hl=en
//
//  Created by Subash Poudel 2014-11-19
//  Copyright (c) 2014 Subash. 
//  this software is licensced under the BEERWARE licence. You are free to do whatever you like with it.

#import "GameScene.h"
@import AVFoundation;

@interface GameScene() <SKPhysicsContactDelegate>
// plays background-music-aac
@property (nonatomic) AVAudioPlayer * backgroundMusicPlayer;
//points for 4 red Lines shown in screen points A,C,E & G are for the emo to appear on screen
@property CGPoint pointA;
@property CGPoint pointB;
@property CGPoint pointC;
@property CGPoint pointD;
@property CGPoint pointE;
@property CGPoint pointF;
@property CGPoint pointG;
@property CGPoint pointH;
//pts A,C,E & G to randomly show sprites
@property NSArray *startPointArray;
// for showing new emo objects
@property (nonatomic) NSTimeInterval lastSpawnTimeInterval;
@property (nonatomic) NSTimeInterval lastUpdateTimeInterval;
// 4 points the dog is allowed to move
@property CGPoint dogCenterTopLeft;
@property CGPoint dogCenterTopRight;
@property CGPoint dogCenterBottomLeft;
@property CGPoint dogCenterBottomRight;
// lives and score
@property int score;
@property int lives;
// score and life heart
@property SKLabelNode *scoreLabel;
@property SKSpriteNode *livesSpriteOne;
@property SKSpriteNode *livesSpriteTwo;
@property SKSpriteNode *livesSpriteThree;
// initial gravity = -9.8 default
@property float gravityValue;
// sounds
@property SKAction* eatingSound;
@property SKAction* backgroundMusic;
// rate at which smiley's are generated default is 1 every 0.8 seconds
@property float smileyGenerationRate;
@end
// helper method
static inline CGPoint addToPoint(CGPoint point,int x, int y){
    return CGPointMake(point.x + x, point.y + y);
}
// for collision detection detected at bottom of the screen and dogs mouth
// bitmask operation
static const uint32_t smileyCategory = 1 << 0;
static const uint32_t bottomEdgeCategory = 1 << 1;
static const uint32_t dogMouthCategory = 1 << 2;
// sprite of dog
SKSpriteNode *dogSprite;

@implementation GameScene

-(instancetype) initWithSize:(CGSize)size{
    if (self = [super initWithSize:size]) {
        // apply default values
        self.smileyGenerationRate = 0.8;
        self.score = 0;
        self.lives = 3;
        self.gravityValue = -9.8;
        //initializing sounds
        self.eatingSound = [SKAction playSoundFileNamed:@"pew-pew-lei.caf" waitForCompletion:NO];
        //background color is blue
        self.backgroundColor = [SKColor colorWithRed:0.68 green:0.82 blue:0.82 alpha:1];
        //screen width and height
        float width = size.width;
        float height = size.height;
        // the whole bound of screen is a physics body so that the sprites cannot go out of frame
        self.physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame];
        // set the contact delegate for collisions
        self.physicsWorld.contactDelegate = self;
        // the width of the screen is divided into 6 parts and it height to 5 parts
        // dont calculate like this 4/5*height it will give integer division for 4/5
        // these points are used for drawing lines, positioning dog and starting point for smiley
        self.pointA =CGPointMake(0, 4*height/5);
        self.pointB =CGPointMake(width/3, 3*height/5);
        self.pointC =CGPointMake(0, 2*height/5);
        self.pointD =CGPointMake(width/3, 1*height/5);
        self.pointE =CGPointMake(width, 4*height/5);
        self.pointF =CGPointMake(2*width/3, 3*height/5);
        self.pointG =CGPointMake(width, 2*height/5);
        self.pointH =CGPointMake(2*width/3, 1*height/5);
        
        //creating dog sprites
        dogSprite = [SKSpriteNode spriteNodeWithImageNamed:@"dog"];
        int dogSpriteWidth = dogSprite.size.width/2;
        int dogSpriteHeight = dogSprite.size.height/2;
        //calculating dog center points dog's mouth is positioned at the end of each line towards the center
        self.dogCenterTopLeft = addToPoint(self.pointB,dogSpriteWidth, -dogSpriteHeight);
        self.dogCenterTopRight = addToPoint(self.pointF,-dogSpriteWidth, -dogSpriteHeight);
        self.dogCenterBottomLeft = addToPoint(self.pointD,dogSpriteWidth, -dogSpriteHeight);
        self.dogCenterBottomRight = addToPoint(self.pointH,-dogSpriteWidth, -dogSpriteHeight);
        //initial position of dog
        dogSprite.position = self.dogCenterTopLeft;
        dogSprite.physicsBody.dynamic = YES;
        // for collision detection a line is placed in the mouth of the dog if the smiley touches this line it is regarded as the dog ate the sprite and the score is updated
        int dogMouthLineXPos = dogSprite.size.width / 3;
        int dogMouthLineYPos = 3 * dogSprite.size.height / 8;
        // change [SKColor clearColor] to [SKColor redColor] to see the line in the dog's mouth
        SKShapeNode *dogMouthLine = [self drawLineFromPoint:CGPointMake(-dogMouthLineXPos, dogMouthLineYPos) pointB:CGPointMake(dogMouthLineXPos, dogMouthLineYPos) withColor:[SKColor clearColor]];
        dogMouthLine.physicsBody.dynamic = YES;
        // for collision detection
        dogMouthLine.physicsBody.categoryBitMask = dogMouthCategory;
        dogMouthLine.physicsBody.contactTestBitMask = smileyCategory;
        // add the line as a child node of the dogSpriteNode
        [dogSprite addChild:dogMouthLine];
        // add dog to scene
        [self addChild:dogSprite];
        // populate the starting point array for the sprites to appear randomly on screen
        self.startPointArray = [NSArray arrayWithObjects:[NSValue valueWithCGPoint:self.pointA],[NSValue valueWithCGPoint:self.pointC],[NSValue valueWithCGPoint:self.pointE],[NSValue valueWithCGPoint:self.pointG], nil];
        // draw the 4 round lines
        SKShapeNode *lineOne = [self drawLineFromPoint:self.pointA pointB:self.pointB withColor:[SKColor redColor]];
        SKShapeNode *lineTwo = [self drawLineFromPoint:self.pointC pointB:self.pointD withColor:[SKColor redColor]];
        SKShapeNode *lineThree = [self drawLineFromPoint:self.pointE pointB:self.pointF withColor:[SKColor redColor]];
        SKShapeNode *lineFour = [self drawLineFromPoint:self.pointG pointB:self.pointH withColor:[SKColor redColor]];
        // A line at the bottom edge of the screen just 1 pixel above the bottom of the screen. if the smiley touches this line then the live is deduced by 1. After 3 lives its game over.
        CGPoint start = CGPointMake(1, 1);
        CGPoint end = CGPointMake(width-1, 1);
        // change [SKColor clearColor] to [SKColor redColor] below to view the invisible line
        SKShapeNode *bottomLine = [self drawLineFromPoint:start pointB:end withColor:[SKColor clearColor]];
        // make bottom line a physics body for collision detection with smiley
        bottomLine.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:start toPoint:end];
        bottomLine.physicsBody.categoryBitMask = bottomEdgeCategory;
        bottomLine.physicsBody.collisionBitMask = 0;
        bottomLine.physicsBody.contactTestBitMask = smileyCategory;
        // add view elements to screen
        [self addScoreLabel];
        [self addLivesSprites];
        [self addChild:bottomLine];
        [self addChild:lineOne];
        [self addChild:lineTwo];
        [self addChild:lineThree];
        [self addChild:lineFour];
        [self playBackGroundMusic];
        
    }
    
    return self;
}

// method to draw a line between two points
-(SKShapeNode *)drawLineFromPoint : (CGPoint) pointA pointB:(CGPoint) pointB withColor:(SKColor*) color{
    SKShapeNode *yourline = [SKShapeNode node];
    CGMutablePathRef pathToDraw = CGPathCreateMutable();
    CGPathMoveToPoint(pathToDraw, NULL, pointA.x  , pointA.y);
    CGPathAddLineToPoint(pathToDraw, NULL, pointB.x, pointB.y);
    yourline.path = pathToDraw;
    yourline.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:pointA toPoint:pointB];
    yourline.fillColor = color;
    yourline.lineWidth = 2;
    [yourline setStrokeColor:color];
    yourline.physicsBody.dynamic = YES;
    yourline.physicsBody.collisionBitMask = 1<<4;
    return yourline;
}
// adding smiley
-(void) addSmileyAtPoint: (CGPoint) point{
    SKSpriteNode *smiley = [SKSpriteNode spriteNodeWithImageNamed:@"smiley"];
    smiley.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:smiley.size.width/2];
    smiley.position = CGPointMake(point.x, point.y);
    smiley.physicsBody.dynamic = YES;
    smiley.physicsBody.contactTestBitMask = bottomEdgeCategory;
    smiley.physicsBody.categoryBitMask = smileyCategory;
    smiley.physicsBody.collisionBitMask = 1 << 4;
    smiley.physicsBody.friction = 10.0;
    [smiley.physicsBody applyForce:CGVectorMake(10, 10)];
    [self addChild:smiley];
}
- (void)update:(NSTimeInterval)currentTime {
    // Handle time delta.
    // If we drop below 60fps, we still want everything to move the same distance.
    CFTimeInterval timeSinceLast = currentTime - self.lastUpdateTimeInterval;
    self.lastUpdateTimeInterval = currentTime;
    if (timeSinceLast > 1) { // more than a second since last update
        timeSinceLast = 1.0 / 60.0;
        self.lastUpdateTimeInterval = currentTime;
    }
    
    [self updateWithTimeSinceLastUpdate:timeSinceLast];
    
}
- (void)updateWithTimeSinceLastUpdate:(CFTimeInterval)timeSinceLast {
    
    self.lastSpawnTimeInterval += timeSinceLast;
    if (self.lastSpawnTimeInterval > self.smileyGenerationRate) {
        self.lastSpawnTimeInterval = 0;
        int position = arc4random() % 4;
        NSValue *val = [self.startPointArray objectAtIndex:position];
        CGPoint point = [val CGPointValue];
        // place a random smiley at specified point on screen
        [self addSmileyAtPoint:point];
    }
}
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    // the screen is divided into 4 parts topLeft, topRight, bottomLeft and bottomRight. the parts of screen is divided equally in half to get the 4 parts. the parts where you touch acts as new position for the dog
    UITouch * touch = [touches anyObject];
    CGPoint location = [touch locationInNode:self];
    CGPoint moveDogTo;
    int widthHalf = self.size.width / 2;
    int heightHalf = self.size.height / 2;
    if (location.x <= widthHalf) {
            //left side touched
        if (location.y >= heightHalf) {
            moveDogTo = self.dogCenterTopLeft;
        }else{
            moveDogTo = self.dogCenterBottomLeft;
        }
    }else{
        if (location.y >= heightHalf) {
            moveDogTo = self.dogCenterTopRight;
        }else{
            moveDogTo = self.dogCenterBottomRight;
        }
    }
    //move doge from its current point to point moveTo in 0.1 seconds
    [dogSprite runAction:[SKAction moveTo:moveDogTo duration:0.1]];
}
// called when objects collide on screen
-(void)didBeginContact:(SKPhysicsContact *)contact{
    
    // smiley crosses bottomLine of screen
    if (contact.bodyA.categoryBitMask == smileyCategory && contact.bodyB.categoryBitMask == bottomEdgeCategory) {
        // bodyA is smiley so remove it from scene
        [contact.bodyA.node removeFromParent];
        [self deduceLives];
    }
    // smiley crosses bottomLine of screen
    if (contact.bodyB.categoryBitMask == smileyCategory && contact.bodyA.categoryBitMask == bottomEdgeCategory) {
        // bodyB is smiley so remove it from scene
        [contact.bodyB.node removeFromParent];
        [self deduceLives];
    }
    // smiley enters dogs mouth
    if (contact.bodyA.categoryBitMask == smileyCategory && contact.bodyB.categoryBitMask == dogMouthCategory) {
        // bodyA is smiley so remove it from scene
        [contact.bodyA.node removeFromParent];
        [self updateScore];
        
    }
    // smiley enters dogs mouth
    if (contact.bodyB.categoryBitMask == smileyCategory && contact.bodyA.categoryBitMask == dogMouthCategory) {
        // bodyB is smiley so remove it from scene
        [contact.bodyB.node removeFromParent];
        [self updateScore];
    }
}
// the score displayed on screen
-(void)addScoreLabel{
    self.scoreLabel = [SKLabelNode labelNodeWithFontNamed:@"Arial"];
    // This positions the label node in the scene
    self.scoreLabel.position = CGPointMake(self.frame.size.width/2,self.frame.size.height - 50);
    self.scoreLabel.fontSize = 25;
    self.scoreLabel.fontColor = [SKColor blackColor];
    self.scoreLabel.text = [NSString stringWithFormat:@"%d",self.score];
    self.scoreLabel.name = @"stop";
    [self addChild:self.scoreLabel];
}
// lives sprites heart displayed on screen
-(void) addLivesSprites{
    int width = self.size.width -25;
    int height = self.size.height - 25;
    self.livesSpriteOne = [SKSpriteNode spriteNodeWithImageNamed:@"heart_life"];
    self.livesSpriteTwo = [SKSpriteNode spriteNodeWithImageNamed:@"heart_life"];
    self.livesSpriteThree = [SKSpriteNode spriteNodeWithImageNamed:@"heart_life"];
    self.livesSpriteOne.position = CGPointMake(width , height );
    int offsetX =self.livesSpriteOne.size.width;
    width = width - offsetX;
    self.livesSpriteTwo.position = CGPointMake(width , height );
    width = width - offsetX;
    self.livesSpriteThree.position = CGPointMake(width, height);
    [self addChild:self.livesSpriteOne];
    [self addChild:self.livesSpriteTwo];
    [self addChild:self.livesSpriteThree];
}
// smiley crosses the screen boundary so reduce users life
-(void) deduceLives{
    NSLog(@"lives deduced");
    --self.lives;
    switch (self.lives) {
        case 2:
            // change the livesSprite's image to indicate life loss
            [self.livesSpriteThree setTexture:[SKTexture textureWithImageNamed:@"heart_life_gone"]];
            break;
        case 1:
            //self.livesLabelThree = [SKSpriteNode spriteNodeWithImageNamed:@"heart_life_gone"];
            [self.livesSpriteTwo setTexture:[SKTexture textureWithImageNamed:@"heart_life_gone"]];
            break;
        case 0:
            // game over all life finished
            [self.livesSpriteOne setTexture:[SKTexture textureWithImageNamed:@"heart_life_gone"]];
            [self.backgroundMusicPlayer pause];
            [self addGameOverLabel];
             self.scene.view.paused = YES;
            break;
            
        default:
            break;
    }
}
// method to update score
-(void) updateScore{
    [self runAction:self.eatingSound];
    self.scoreLabel.text = [NSString stringWithFormat:@"%d",++self.score];
    if (self.score % 15 == 0) {
        // change gravity and smileyGenerationRate game gets harder
        self.smileyGenerationRate = self.smileyGenerationRate - 0.1;
        self.physicsWorld.gravity = CGVectorMake(0.0f, self.gravityValue - 20);
    }
}
// plays background music
-(void) playBackGroundMusic{
    NSError *error;
    NSURL * backgroundMusicURL = [[NSBundle mainBundle] URLForResource:@"background-music-aac" withExtension:@"caf"];
    self.backgroundMusicPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:backgroundMusicURL error:&error];
    self.backgroundMusicPlayer.numberOfLoops = -1;
    [self.backgroundMusicPlayer prepareToPlay];
    [self.backgroundMusicPlayer play];
}
// game over label
-(void)addGameOverLabel{
    SKLabelNode *myLabel = [SKLabelNode labelNodeWithFontNamed:@"Arial"];
    myLabel.position = CGPointMake(self.frame.size.width/2,self.frame.size.height/2);
    myLabel.fontSize = 50;
    myLabel.fontColor = [SKColor blackColor];
    myLabel.text = @"GAME OVER";
    [self addChild:myLabel];
}
@end
