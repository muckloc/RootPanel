var gulp = require('gulp');
var less = require('gulp-less');
var coffee = require('gulp-coffee');
var uglify = require('gulp-uglify');
var path = require('path');

lessPath = './core/static/style';
coffeePath = './core/static/script';
corePath = './core'

gulp.task('less', function() {
  return gulp.src(lessPath + "/**/*.less").pipe(less()).pipe(gulp.dest(lessPath));
});

gulp.task('coffee', function() {
  gulp.src(corePath + "/**/*.coffee").pipe(coffee({bare:true})).on('error', function(error) {
    throw error;
  }).pipe(uglify()).pipe(gulp.dest(corePath));
  return gulp.src(coffeePath + "/**/*.coffee").pipe(coffee({bare:true})).on('error', function(error) {
    throw error;
  }).pipe(uglify()).pipe(gulp.dest(coffeePath));
});

gulp.task('watch', function(){
  gulp.watch(coffeePath + "/**/*.coffee",['coffee']);
  gulp.watch(corePath + "/**/*.coffee",['coffee']);
  gulp.watch(lessPath + "/**/*.less",['less']);
});

gulp.task('default', ['less', 'coffee', 'watch']);
