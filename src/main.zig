const std = @import("std");

/// BPB (BIOS Parameter Block) for FAT16
const BootSector = struct {
    jmp: [3]u8,
    oem_name: [8]u8,
    bytes_per_sector: u16,
    sectors_per_cluster: u8,
    reserved_sectors: u16,
    num_fats: u8,
    root_entries: u16,
    total_sectors: u16,
    media_descriptor: u8,
    sectors_per_fat: u16,
    sectors_per_track: u16,
    num_heads: u16,
    hidden_sectors: u32,
    total_sectors_large: u32,
};

/// FAT12/16 extended boot record
const ExtendedBootRecord = struct {
    drive_number: u8,
    reserved: u8,
    boot_signature: u8,
    volume_id: u32,
    volume_label: [11]u8,
    fs_type: [8]u8,
};

const DirectoryEntry = struct {
    name: [11]u8,
    attributes: u8,
    reserved: [10]u8,
    creation_time_tenths: u8,
    creation_time: u16,
    creation_date: u16,
    last_access_date: u16,
    first_cluster_high: u16,
    last_modification_time: u16,
    last_modification_date: u16,
    first_cluster_low: u16,
    file_size: u32,
};

pub fn main() !void {
    var allocator = std.heap.c_allocator;

    // read command line argument
    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    // this is for debugging purposes
    if (args.len != 2 and false) {
        std.debug.print("invalid number of arguments: {}\n", .{args.len});
        try std.io.getStdErr().writeAll("Usage: fat <fat-formatted disk image>\n");
        return;
    }

    // const disk_image_path = args[1];
    const disk_image_path = "/Users/jvf/test_disk.img";
    std.debug.print("reading disk image: {s}\n", .{disk_image_path});
    var disk_image = try std.fs.cwd().openFile(disk_image_path, .{});
    defer disk_image.close();
    const reader = disk_image.reader();

    var bpb: BootSector = undefined;
    _ = try reader.readAll(&bpb.jmp);
    _ = try reader.readAll(&bpb.oem_name);
    bpb.bytes_per_sector = try reader.readInt(u16, .little);
    bpb.sectors_per_cluster = try reader.readInt(u8, .little);
    bpb.reserved_sectors = try reader.readInt(u16, .little);
    bpb.num_fats = try reader.readInt(u8, .little);
    bpb.root_entries = try reader.readInt(u16, .little);
    bpb.total_sectors = try reader.readInt(u16, .little);
    bpb.media_descriptor = try reader.readInt(u8, .little);
    bpb.sectors_per_fat = try reader.readInt(u16, .little);
    bpb.sectors_per_track = try reader.readInt(u16, .little);
    bpb.num_heads = try reader.readInt(u16, .little);
    bpb.hidden_sectors = try reader.readInt(u32, .little);
    bpb.total_sectors_large = try reader.readInt(u32, .little);
    std.debug.print("JMP: {x} {x} {x}\n", .{bpb.jmp[0], bpb.jmp[1], bpb.jmp[2]});
    std.debug.print("OEM identifier: {s}\n", .{bpb.oem_name});
    std.debug.print("Bytes per sector: {}\n", .{bpb.bytes_per_sector});
    std.debug.print("Sectors per cluster: {}\n", .{bpb.sectors_per_cluster});
    std.debug.print("Reserved sectors: {}\n", .{bpb.reserved_sectors});
    std.debug.print("Number of FATs: {}\n", .{bpb.num_fats});
    std.debug.print("Root entries: {}\n", .{bpb.root_entries});
    std.debug.print("Total sectors: {}\n", .{bpb.total_sectors});
    std.debug.print("Media descriptor: {}\n", .{bpb.media_descriptor});
    std.debug.print("Sectors per FAT: {}\n", .{bpb.sectors_per_fat});
    std.debug.print("Sectors per track: {}\n", .{bpb.sectors_per_track});
    std.debug.print("Number of heads: {}\n", .{bpb.num_heads});
    std.debug.print("Hidden sectors: {}\n", .{bpb.hidden_sectors});
    std.debug.print("Total sectors (large): {}\n", .{bpb.total_sectors_large});

    var ebp: ExtendedBootRecord = undefined;
    ebp.drive_number = try reader.readInt(u8, .little);
    ebp.reserved = try reader.readInt(u8, .little);
    ebp.boot_signature = try reader.readInt(u8, .little);
    ebp.volume_id = try reader.readInt(u32, .little);
    _ = try reader.readAll(&ebp.volume_label);
    _ = try reader.readAll(&ebp.fs_type);

    std.debug.print("Drive number: {}\n", .{ebp.drive_number});
    std.debug.print("Reserved: {}\n", .{ebp.reserved});
    std.debug.print("Boot signature: {}\n", .{ebp.boot_signature});
    std.debug.print("Volume ID: {}\n", .{ebp.volume_id});
    std.debug.print("Volume label: {s}\n", .{ebp.volume_label});
    std.debug.print("File system type: {s}\n", .{ebp.fs_type});

    const bootcode = try reader.readUntilDelimiterAlloc(allocator, 0xAA, 512);
    defer allocator.free(bootcode);

    const fat_table_size = bpb.sectors_per_fat * bpb.bytes_per_sector;
    std.debug.print("FAT table size: {}B\n", .{fat_table_size});

    const fat_table1 = try allocator.alloc(u8, fat_table_size);
    defer allocator.free(fat_table1);
    _ = try reader.readAll(fat_table1);

    const fat_table2 = try allocator.alloc(u8, fat_table_size);
    defer allocator.free(fat_table2);
    _ = try reader.readAll(fat_table2);

    const root_dir_size = bpb.root_entries * 32;
    std.debug.print("Root directory size: {}B\n", .{root_dir_size});
    const root_dir = try allocator.alloc(DirectoryEntry, bpb.root_entries);

    // root_dir_sectors = ((fat_boot->root_entry_count * 32) + (fat_boot->bytes_per_sector - 1)) / fat_boot->bytes_per_sector;
    const root_dir_sectors = ((bpb.root_entries * 32) + (bpb.bytes_per_sector - 1)) / bpb.bytes_per_sector;
    std.debug.print("root_dir_sectors: {x}\n", .{root_dir_sectors});
    
    std.debug.print("Root directory entries:\n", .{});
    for (root_dir) |*entry| {
        _ = try reader.readAll(&(entry.name));
        entry.attributes = try reader.readInt(u8, .little);
        _ = try reader.readAll(&(entry.reserved));
        entry.creation_time_tenths = try reader.readInt(u8, .little);
        entry.creation_time = try reader.readInt(u16, .little);
        entry.creation_date = try reader.readInt(u16, .little);
        entry.last_access_date = try reader.readInt(u16, .little);
        entry.first_cluster_high = try reader.readInt(u16, .little);
        entry.last_modification_time = try reader.readInt(u16, .little);
        entry.last_modification_date = try reader.readInt(u16, .little);
        entry.first_cluster_low = try reader.readInt(u16, .little);
        entry.file_size = try reader.readInt(u32, .little);
        std.debug.print("- entry: {s} {}B\n", .{entry.name, entry.file_size});
    }
}
