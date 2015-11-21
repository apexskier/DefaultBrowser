import gulp from 'gulp';
import autoprefixer from 'gulp-autoprefixer';
import babel from 'gulp-babel';
import browserify from 'browserify';
import csscomb from 'gulp-csscomb';
import del from 'del';
import eslint from 'gulp-eslint';
import glob from 'glob';
import imagemin from 'gulp-imagemin';
import inject from 'gulp-inject';
import minifyCss from 'gulp-minify-css';
import sass from 'gulp-sass';
import source from 'vinyl-source-stream';
import sourcemaps from 'gulp-sourcemaps';
import streamify from 'gulp-streamify';
import uglify from 'gulp-uglify';
import uncss from 'gulp-uncss';

const paths = {
    gulp: [__filename, 'gulp/**/*.js'],
    html: ['index.html'],
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
        .pipe(sourcemaps.write('.'))
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
            .pipe(uncss({html: paths.html}))
            .pipe(autoprefixer())
            .pipe(minifyCss())
        .pipe(sourcemaps.write('.'))
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
