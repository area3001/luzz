////////////////////////////////////////////////////
//
//	First test of game of life by conway on Luzz
//		14-06-2014 by Wim Van Gool
//
////////////////////////////////////////////////////

import org.eclipse.paho.client.mqttv3.internal.*;
import org.eclipse.paho.client.mqttv3.persist.*;
import org.eclipse.paho.client.mqttv3.internal.wire.*;
import org.eclipse.paho.client.mqttv3.internal.security.*;
import org.eclipse.paho.client.mqttv3.util.*;
import org.eclipse.paho.client.mqttv3.logging.*;
import org.eclipse.paho.client.mqttv3.*;

//import se.goransson.mqtt.*;

import java.util.Arrays;

MqttClient client;
MqttMessage message;

// Size of cells
int cellSize = 7;

// How likely for a cell to be alive at start (in percentage)
float probabilityOfAliveAtStart = 15;

// Variables for timer
int lastRecordedTime = 0;
int reset_delay = 300;  // multiply by totalTime in msec. 600 * 100 = 60 sec
int reset_counter = 0;

// Colors for active/inactive cells
color alive = color(50, 200, 100);
color dead = color(50, 0, 0);
color untouched = color(0, 10, 0);

// Array of cells
int[][] cells; 
// Buffer to record the state of the cells and use this while changing the others in the interations
int[][] cellsBuffer; 
int savedTime;
int totalTime = 100;  //in msec
int img_size_height = 40; //20
int img_size_width = 92; //46

// Pause
boolean pause = false;

class MyFrame {
  int bottom = 0;
  int left = 0;
  int right = 0;
  int top = 0;
  byte[] payload;

  public MyFrame(int bottom, int top, int left, int right) { 
    this.bottom = bottom;
    this.top = top;
    this.left = left;
    this.right = right;  
    this.payload = new byte[(top - bottom + 1) * (right - left + 1) * 3];
  }
};

// init
MyFrame frame0 = new MyFrame(0, 19, 0, 45);  // top left don't make errors here: it wont work :)
MyFrame frame1 = new MyFrame(20, 39, 0, 45); // bottom left above frame zero: (20,39,0,45);
MyFrame frame2 = new MyFrame(20, 39, 46, 91); // bottom right
MyFrame frame3 = new MyFrame(0, 19, 46, 91);  // top right
MyFrame frame4 = new MyFrame(0, 19, 0, 45);
MyFrame frame5 = new MyFrame(0, 19, 0, 45);
MyFrame frame6 = new MyFrame(0, 19, 0, 45);
MyFrame[] frames = {
  frame0, frame1, frame2, frame3, frame4, frame5, frame6
};


void setup() {
  try {
    client = new MqttClient("tcp://localhost:1883", "pahomqttpublish1");
    client.connect();
  } 
  catch (MqttException e) {
    e.printStackTrace();
    exit();
  }

  colorMode(RGB, 255);  	

  size (img_size_width*cellSize, img_size_height*cellSize);

  // Instantiate arrays 
  cells = new int[img_size_width][img_size_height];
  cellsBuffer = new int[img_size_width][img_size_height];

  // This stroke will draw the background grid
  stroke(48);

  noSmooth();

  // Initialization of cells
  init_cells();

  savedTime = millis();
  background(0); // Fill in black in case cells don't cover all the windows
  noLoop();
}

void init_cells() {
  for (int x=0; x<width/cellSize; x++) {
    for (int y=0; y<height/cellSize; y++) {
      float state = random (100);
      if (state > probabilityOfAliveAtStart) { 
        state = -1; //untouched
      }
      else {
        state = 1;
      }
      cells[x][y] = int(state); // Save state of each cell
    }
  }
}
void draw() {

  //Draw grid
  for (int x=0; x<width/cellSize; x++) {
    for (int y=0; y<height/cellSize; y++) {
      if (cells[x][y]==1) {
        fill(alive); // If alive
      }
      else {
        if (cells[x][y] == 0)
          fill(dead); // If dead
        else 
          fill(untouched);
      }
      rect (x*cellSize, y*cellSize, cellSize, cellSize);
    }
  }
}



void iteration() { // When the clock ticks
  // Save cells to buffer (so we opeate with one array keeping the other intact)
  for (int x=0; x<width/cellSize; x++) {
    for (int y=0; y<height/cellSize; y++) {
      cellsBuffer[x][y] = cells[x][y];
    }
  }

  // Visit each cell:
  for (int x=0; x<width/cellSize; x++) {
    for (int y=0; y<height/cellSize; y++) {
      // And visit all the neighbours of each cell
      int neighbours = 0; // We'll count the neighbours
      for (int xx=x-1; xx<=x+1;xx++) {
        for (int yy=y-1; yy<=y+1;yy++) {  
          if (((xx>=0)&&(xx<width/cellSize))&&((yy>=0)&&(yy<height/cellSize))) { // Make sure you are not out of bounds
            if (!((xx==x)&&(yy==y))) { // Make sure to to check against self
              if (cellsBuffer[xx][yy]==1) {
                neighbours ++; // Check alive neighbours and count them
              }
            } // End of if
          } // End of if
        } // End of yy loop
      } //End of xx loop
      // We've checked the neigbours: apply rules!
      if (cellsBuffer[x][y]==1) { // The cell is alive: kill it if necessary
        if (neighbours < 2 || neighbours > 3) {
          cells[x][y] = 0; // Die unless it has 2 or 3 neighbours
        }
      } 
      else { // The cell is dead: make it live if necessary      
        if (neighbours == 3 ) {
          cells[x][y] = 1; // Only if it has 3 neighbours
        }
      } // End of if
    } // End of y loop
  } // End of x loop
} // End of function

void grab_and_send() {
  byte tempR, tempG, tempB;

  for (int h = 0; h < frames.length; h++) {
    int loc_frame = 0;
    for (int i = frames[h].bottom; i < frames[h].top + 1; i++) {
      for (int j = frames[h].left; j < frames[h].right + 1; j++) {    
        if ( cells[j][i] == 1 ) {
          //cell is alive
          tempR = byte(red(alive)); // can also do with red = c >> 16 & 0xFF;
          tempG = byte(green(alive));
          tempB = byte(blue(alive));
        }
        else {
          if ( cells[j][i] == 0) {
            //cell is dead
            tempR = byte(red(dead)); // can also do with red = c >> 16 & 0xFF;
            tempG = byte(green(dead));
            tempB = byte(blue(dead));
          }
          else {
            //cell is untouched
            tempR = byte(red(untouched)); // can also do with red = c >> 16 & 0xFF;
            tempG = byte(green(untouched));
            tempB = byte(blue(untouched));
          }
        }

        frames[h].payload[loc_frame]=tempR;
        frames[h].payload[loc_frame+1]=tempG;
        frames[h].payload[loc_frame+2]=tempB;

        loc_frame += 3;
      }
    }

    //printArray(payload);
    //mqtt.publish("/luzz/1", Arrays.toString(payload));

    // Calculate how much time has passed

    try {
      message = new MqttMessage();
      message.setPayload(frames[h].payload);
      message.setQos(0);
      //println(h);
      client.publish("/luzz/" + h, message); // Qos = 0
      print("publishing iteration to /luzz/" + h);
      //client.disconnect();
    }
    catch (MqttException e) {
      e.printStackTrace();
      print ("error");
    }
  }
}

void mousePressed() {
  int passedTime;
  println("Started...");
  while (true) {  
    // Calculate how much time has passed
    passedTime = millis() - savedTime;
    // Has x seconds passed?
    if (passedTime > totalTime) {
      savedTime = millis(); // Save the current time to restart the timer!
      println ("Passed: " + passedTime);

      reset_counter ++;
      if (reset_counter == reset_delay) {
        init_cells();
        reset_counter=0;
      }

      iteration();
      grab_and_send();  //compose and send MQTT message
      redraw();
    }
  }
}

