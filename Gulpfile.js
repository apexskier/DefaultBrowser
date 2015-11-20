var gulp = require('gulp'),
    autoprefixer = require('gulp-autoprefixer'),
    babel = require('gulp-babel'),
    browserify = require('browserify'),
    csscomb = require('gulp-csscomb'),
    del = require('del'),
    eslint = require('gulp-eslint'),
    glob = require('glob'),
    imagemin = require('gulp-imagemin'),
    inject = require('gulp-inject'),
    sass = require('gulp-sass'),
    source = require('vinyl-source-stream'),
    sourcemaps = require('gulp-sourcemaps'),
    streamify = require('gulp-streamify'),
    uglify = require('gulp-uglify'),

    paths = {
        gulp: ['Gulpfile.js', 'gulp/**/*.js'],
        html: 'index.html',
        media: 'src/media/**/*',
        scripts: 'src/**/*.js',
        styles: 'src/**/*.scss',
        sources: ['dst/**/*.js', 'dst/**/*.css']
    };

gulp.task('scripts', gulp.series(compileScripts, bundleScripts));
gulp.task('build', gulp.series(clean, gulp.parallel(media, 'scripts', styles), html));
gulp.task(clean);
gulp.task(format);
gulp.task(watch);

gulp.task('default', gulp.series('build', watch));

function clean() {
    return del(['dst']);
}

function eslintStream(src, options) {
    return gulp.src(src, options).pipe(eslint()).pipe(eslint.format());
}

function format() {
    return gulp.src(paths.styles, {base: __dirname})
        .pipe(csscomb())
        .pipe(gulp.dest('.'));
}

function html() {
    return gulp.src(paths.html)
        .pipe(gulp.dest('dst')) // change file path so relative works
        .pipe(inject(gulp.src(paths.sources, {
            read: false
        }), {relative: true}))
        .pipe(gulp.dest('dst'));
}

function media() {
    return gulp.src(paths.media, {since: gulp.lastRun(media)})
        .pipe(imagemin())
        .pipe(gulp.dest('dst/media'));
}

function compileScripts() {
    return eslintStream(paths.scripts, {since: gulp.lastRun(compileScripts)})
        .pipe(sourcemaps.init())
        .pipe(babel())
        .pipe(sourcemaps.write())
        .pipe(gulp.dest('tmp'));
}

function bundleScripts() {
    return browserify(glob.sync('tmp/**/[^_]*.js'), {debug: true}).bundle()
        .pipe(source('index.js'))
        .pipe(streamify(uglify()))
        .pipe(gulp.dest('dst'));
}

function styles() {
    return gulp.src(paths.styles)
        .pipe(sourcemaps.init())
            .pipe(sass({outputStyle: 'compressed'}).on('error', sass.logError))
            .pipe(autoprefixer())
        .pipe(sourcemaps.write())
        .pipe(gulp.dest('dst'));
}

function validateGulp() {
    return eslintStream(paths.gulp);
}

function watch() {
    gulp.watch(paths.gulp, validateGulp);
    gulp.watch(paths.media, media);
    gulp.watch(paths.scripts, gulp.series('scripts'));
    gulp.watch(paths.styles, styles);
    gulp.watch([paths.sources, paths.html], html);
}
