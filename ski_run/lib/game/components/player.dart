class Player {
  double x = 0.0; // lateral position (-1 to 1, 0 = center)
  double speed = 0.0;
  int turnDir = 0; // -1 left, 0 none, 1 right
  int touchSide = 0;

  void reset() {
    x = 0.0;
    speed = 0.0;
    turnDir = 0;
    touchSide = 0;
  }
}
