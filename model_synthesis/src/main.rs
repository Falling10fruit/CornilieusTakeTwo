use image;

fn main() {
    const WIDTH:usize = 50;
    const HEIGHT:usize = 50;

    // let mut image_buffer = image::ImageBuffer::new(width, height);

    // for (x, y, pixel) in image_buffer.enumerate_pixels_mut() {
    //     *pixel = image::Rgb([x, y, 1]);
    // }

    let mut raw_8buffer = [0u8; WIDTH * HEIGHT * 3];

    for x in 0..WIDTH {
        for y in 0..HEIGHT {
            let index = (x + y * WIDTH) * 3;
            raw_8buffer[index + 0] = x as u8;
            raw_8buffer[index + 1] = y as u8;
            raw_8buffer[index + 2] = 255;
        }
    }

    image::save_buffer("image_png", &raw_8buffer, WIDTH as u32, HEIGHT as u32, image::ExtendedColorType::Rgb8).unwrap();
}
