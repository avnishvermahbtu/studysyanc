class Routine {
  String title;
  String type;
  String location;
  String startTime;
  String endTime;
  String day;
  Routine({
    required this.title,
    required this.type,
    required this.location,
    required this.startTime,
    required this.endTime,
    required this.day,
});
  Map<String,dynamic> toMap(){
    return{
      "title":title,
      "type":type,
      "location":location,
      "startTime":startTime,
      "endTime":endTime,
      "day":day
    };
  }
}