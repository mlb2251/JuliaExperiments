/// Test function that prints hello world
/// This function is exported with C linkage so Julia can call it
#[unsafe(no_mangle)]
pub extern "C" fn hello_world() {
    println!("Hello World from Rust!");
}

/// Test function that takes a name and prints a greeting
/// Returns the length of the greeting message
#[unsafe(no_mangle)]
pub extern "C" fn greet(name_ptr: *const i8, name_len: usize) -> usize {
    if name_ptr.is_null() {
        return 0;
    }
    
    // Convert C string to Rust string
    let name_slice = unsafe { std::slice::from_raw_parts(name_ptr as *const u8, name_len) };
    if let Ok(name) = std::str::from_utf8(name_slice) {
        let greeting = format!("Hello, {}! Greetings from Rust backend.", name);
        println!("{}", greeting);
        greeting.len()
    } else {
        println!("Invalid UTF-8 in name");
        0
    }
}

/// Simple math function to test basic FFI
#[unsafe(no_mangle)] 
pub extern "C" fn add_numbers(a: i32, b: i32) -> i32 {
    // sleep for 1 second
    std::thread::sleep(std::time::Duration::from_secs(5));
    a + b
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add_numbers() {
        assert_eq!(add_numbers(2, 3), 5);
    }
}
